-- 核心 SQL 示例
-- 这些语句是 SQL 适配器的实现参考；业务判断仍然在 service 层。
-- 占位符用 $1 / $2，实际驱动里换成参数绑定，禁止字符串拼接。

-- ---------------------------------------------------------------------------
-- 1. 报名：一个事务内完成「扣名额 + 写报名记录 + 写消息」
-- ---------------------------------------------------------------------------
-- 调用前先做：
--   select 1 from activity_sign where idempotency_key = $3 and is_cancel = false;
--   如果命中，直接返回已有记录（幂等）。
--   如果命中但 user_id / activity_id 不一致，返回 IDEMPOTENCY_KEY_REUSED。
--
-- 下面按「先锁活动行，再写报名行」的固定顺序，避免和取消报名互相死锁。

begin;

-- 条件扣减：rowcount = 1 才算占到名额。
-- 不要写 select remain_count; if (remain > 0) update ...，那是 TOCTOU。
update activity
set remain_count = remain_count - 1,
    version = version + 1,
    updated_at = now()
where activity_id = $1
  and status = 'open'
  and remain_count > 0;

-- 如果 rowcount = 0：rollback，返回 NO_SEAT / NOT_IN_SIGN_PERIOD。

insert into activity_sign (activity_id, user_id, sign_time, idempotency_key)
values ($1, $2, now(), $3);

-- 如果唯一索引 uk_sign_active 冲突：rollback，返回 ALREADY_SIGNED。
-- 如果唯一索引 uk_sign_idempotency 冲突：rollback，返回 IDEMPOTENCY_KEY_REUSED。

insert into message (user_id, title, content, message_type)
values ($2, '报名成功', '活动报名成功，请按时参加。', 'signup');

commit;

-- ---------------------------------------------------------------------------
-- 2. 取消报名：先锁活动行，再锁报名行，最后归还名额
-- ---------------------------------------------------------------------------
begin;

select activity_id
from activity
where activity_id = $1
for update;

select sign_id
from activity_sign
where activity_id = $1
  and user_id = $2
  and is_cancel = false
for update;

-- 没有未取消记录：查一下是否已经取消过，做幂等返回；否则返回 NOT_SIGNED。
-- if found:
update activity_sign
set is_cancel = true,
    cancel_time = now()
where sign_id = $3;

update activity
set remain_count = remain_count + 1,
    version = version + 1,
    updated_at = now()
where activity_id = $1
  and remain_count < max_count;

insert into message (user_id, title, content, message_type)
values ($2, '取消报名', '报名已取消，名额已归还。', 'cancel');

commit;

-- ---------------------------------------------------------------------------
-- 3. 活动列表（只返回可报名 / 公开的活动）
-- ---------------------------------------------------------------------------
select a.activity_id,
       a.club_id,
       c.club_name,
       a.title,
       a.location,
       a.status,
       a.remain_count,
       a.max_count,
       a.sign_start,
       a.sign_end,
       a.activity_time
from activity a
join club c on c.club_id = a.club_id
where a.status = 'open'
order by a.sign_start asc, a.activity_id desc
limit $1 offset $2;

-- ---------------------------------------------------------------------------
-- 4. 报名名单（负责人 / 管理员）
-- ---------------------------------------------------------------------------
select s.sign_id,
       s.user_id,
       u.student_id,
       u.name,
       u.college,
       u.phone,
       s.sign_time,
       s.is_checkin
from activity_sign s
join app_user u on u.user_id = s.user_id
where s.activity_id = $1
  and s.is_cancel = false
order by s.sign_time asc;

-- ---------------------------------------------------------------------------
-- 5. 社团活动统计
-- ---------------------------------------------------------------------------
select a.activity_id,
       a.title,
       a.max_count,
       sum(case when s.is_cancel = false then 1 else 0 end) as signed_count,
       sum(case when s.is_cancel = false and s.is_checkin then 1 else 0 end) as checked_in_count
from activity a
left join activity_sign s on s.activity_id = a.activity_id
where a.club_id = $1
group by a.activity_id, a.title, a.max_count
order by a.sign_start desc;

-- ---------------------------------------------------------------------------
-- 6. 社团审核（一个事务内改社团状态 + 升级负责人角色）
-- ---------------------------------------------------------------------------
begin;

update club
set status = 'active'
where club_id = $1
  and status = 'pending';

-- rowcount = 0：社团不存在或不在待审核状态，rollback。

update app_user
set role = 'club_leader'
where user_id = (select leader_id from club where club_id = $1);

insert into audit_log (actor_id, action, target_type, target_id, detail)
values ($2, 'approve_club', 'club', $1, jsonb_build_object('source', 'admin_console'));

commit;
