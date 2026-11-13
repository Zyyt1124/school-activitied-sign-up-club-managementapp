-- 校园活动与社团管理平台：初始化 schema
-- 目标数据库：PostgreSQL 14+ / 华为云 GaussDB（兼容 PostgreSQL 语法）
--
-- 端云边界：只有云侧仓颉服务连接这个库。端侧永远不持有数据库地址和凭据，
-- 也不直接执行 SQL。所有写操作通过 Repository + TxRunner 完成。

-- ---------------------------------------------------------------------------
-- 用户
-- ---------------------------------------------------------------------------
create table if not exists app_user (
    user_id        bigserial primary key,
    student_id     varchar(32)  not null unique,
    name           varchar(64)  not null,
    role           varchar(16)  not null check (role in ('student', 'club_leader', 'admin')),
    college        varchar(64),
    phone          varchar(20),
    password_hash  varchar(255) not null,
    status         varchar(16)  not null default 'active' check (status in ('active', 'disabled')),
    created_at     timestamptz  not null default now()
);

comment on table app_user is '用户；password_hash 只存服务端哈希，禁止下发端侧';

-- ---------------------------------------------------------------------------
-- 社团
-- ---------------------------------------------------------------------------
create table if not exists club (
    club_id     bigserial primary key,
    club_name   varchar(64) not null,
    intro       text,
    leader_id   bigint      not null references app_user(user_id),
    status      varchar(16) not null check (status in ('pending', 'active', 'disabled')),
    created_at  timestamptz not null default now()
);

comment on table club is '社团；status=pending 时由学校管理员审核';

-- ---------------------------------------------------------------------------
-- 活动
-- ---------------------------------------------------------------------------
create table if not exists activity (
    activity_id   bigserial primary key,
    club_id       bigint       not null references club(club_id),
    title         varchar(128) not null,
    description   text,
    location      varchar(128),
    max_count     int          not null check (max_count > 0),
    remain_count  int          not null check (remain_count >= 0 and remain_count <= max_count),
    sign_start    timestamptz  not null,
    sign_end      timestamptz  not null,
    activity_time timestamptz  not null,
    status        varchar(16)  not null check (status in ('draft', 'open', 'closed', 'archived', 'disabled')),
    version       int          not null default 0,
    created_at    timestamptz  not null default now(),
    updated_at    timestamptz  not null default now(),
    constraint ck_activity_sign_period check (sign_start < sign_end),
    constraint ck_activity_time check (sign_end <= activity_time)
);

comment on column activity.remain_count is '剩余名额；只能由条件 UPDATE 原子修改，禁止先查后改';
comment on column activity.version is '乐观锁版本号；编辑活动时带上 version';

-- ---------------------------------------------------------------------------
-- 报名记录
-- ---------------------------------------------------------------------------
create table if not exists activity_sign (
    sign_id          bigserial primary key,
    activity_id      bigint      not null references activity(activity_id),
    user_id          bigint      not null references app_user(user_id),
    sign_time        timestamptz not null default now(),
    is_cancel        boolean     not null default false,
    cancel_time      timestamptz,
    is_checkin       boolean     not null default false,
    checkin_time     timestamptz,
    idempotency_key  varchar(96),
    created_at       timestamptz not null default now()
);

comment on table activity_sign is '报名记录；取消后保留行，用于审计与重复报名判断';

-- 同一个活动、同一个用户只能有一条「未取消」记录。
-- 取消后可以重新报名，所以用 partial unique index，而不是普通唯一索引。
create unique index if not exists uk_sign_active
    on activity_sign(activity_id, user_id)
    where is_cancel = false;

-- 幂等键全局唯一；NULL 允许多行（PostgreSQL / GaussDB 的唯一索引语义）。
create unique index if not exists uk_sign_idempotency
    on activity_sign(idempotency_key)
    where idempotency_key is not null;

-- ---------------------------------------------------------------------------
-- 消息
-- ---------------------------------------------------------------------------
create table if not exists message (
    message_id    bigserial primary key,
    user_id       bigint       not null references app_user(user_id),
    title         varchar(128) not null,
    content       text         not null,
    message_type  varchar(32)  not null,
    is_read       boolean      not null default false,
    created_at    timestamptz  not null default now()
);

comment on table message is '站内消息；推送失败时应用内消息中心兜底';

-- ---------------------------------------------------------------------------
-- 审计日志
-- ---------------------------------------------------------------------------
create table if not exists audit_log (
    audit_id     bigserial primary key,
    actor_id     bigint references app_user(user_id),
    action       varchar(64) not null,
    target_type  varchar(32),
    target_id    bigint,
    detail       jsonb,
    created_at   timestamptz not null default now()
);

comment on table audit_log is '管理员审核 / 下架 / 导出名单等敏感操作留痕';

-- ---------------------------------------------------------------------------
-- 索引
-- ---------------------------------------------------------------------------
create index if not exists idx_club_status on club(status);

create index if not exists idx_activity_status_sign_start
    on activity(status, sign_start);
create index if not exists idx_activity_club_status
    on activity(club_id, status);

create index if not exists idx_sign_activity
    on activity_sign(activity_id, is_cancel);
create index if not exists idx_sign_user
    on activity_sign(user_id, sign_time desc);

create index if not exists idx_message_user_read
    on message(user_id, is_read, created_at desc);

create index if not exists idx_audit_created
    on audit_log(created_at desc);
