-- 演示种子数据（仅本地 / 测试环境）
-- 密码统一为 123456；password_hash 用 "demo:明文" 只是为了课程演示，
-- 生产环境必须换成 Argon2id / bcrypt 的哈希，并且加盐。

insert into app_user (student_id, name, role, college, phone, password_hash)
values
    ('admin',    '学校管理员', 'admin',       '学生工作处', '',           'demo:123456'),
    ('leader',   '林同学',     'club_leader', '计算机学院', '13800000002', 'demo:123456'),
    ('student',  '朱同学',     'student',     '软件学院',   '13800000003', 'demo:123456'),
    ('student2', '严同学',     'student',     '外国语学院', '13800000004', 'demo:123456')
on conflict (student_id) do nothing;

insert into club (club_name, intro, leader_id, status)
select '开源技术社',
       '面向全校的技术分享与开源实践社团。',
       u.user_id,
       'active'
from app_user u
where u.student_id = 'leader'
  and not exists (select 1 from club where club_name = '开源技术社');

insert into activity (
    club_id, title, description, location,
    max_count, remain_count, sign_start, sign_end, activity_time, status
)
select c.club_id,
       v.title,
       v.description,
       v.location,
       v.max_count,
       v.max_count,
       now() - interval '1 hour',
       now() + v.sign_days * interval '1 day',
       now() + (v.sign_days + 1) * interval '1 day',
       'open'
from club c
cross join (values
    ('鸿蒙原生应用开发分享会', '从 Stage 模型到端云协同，带你把一个校园应用从 0 跑通。', '图书馆报告厅', 50, 7),
    ('仓颉语言入门工作坊', '类型系统、模式匹配、事务边界：用仓颉写一遍报名业务。', '实验楼 A305', 30, 5),
    ('校园社团招新市集', '全校社团集中摆摊，现场咨询、扫码报名、领取社团手册。', '中心广场', 200, 3)
) as v(title, description, location, max_count, sign_days)
where c.club_name = '开源技术社'
  and not exists (select 1 from activity where title = v.title);
