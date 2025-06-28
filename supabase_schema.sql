-- Supabase/Postgres 建表SQL，基于 Flutter 团队记账项目数据模型

-- 行程表
create table trips (
  id serial primary key,
  group_code text not null,         -- 团号/名称
  start_date date,                  -- 行程开始日期
  end_date date,                    -- 行程结束日期
  date date not null,               -- 兼容旧字段，默认用start_date
  people_count integer,             -- 人数，可选
  remark text                       -- 备注，可选
);

-- 收支记录表
create table records (
  id serial primary key,
  trip_id integer not null references trips(id) on delete cascade, -- 所属行程
  type smallint not null,              -- 0:expense, 1:income
  category text not null,              -- 分类
  amount numeric(12,2) not null,       -- 金额
  time timestamptz not null,           -- 记录时间
  remark text,                         -- 备注
  pay_method text,                     -- 支付方式
  share_ratio numeric(5,2),            -- 分成比例
  share_amount numeric(12,2),          -- 分成金额
  detail text                          -- 额外明细
);

-- 用户表建议直接用 Supabase 自带 auth.users，无需自建。
