# 光子招聘实习生通关手册 · 多用户版部署指南

## 一、架构说明

```
┌─────────────────────┐      ┌──────────────────────┐
│  GitHub Pages       │      │  Supabase Cloud      │
│  (静态前端)          │ ←──→ │  (数据库+认证)        │
│  index.html         │      │  PostgreSQL + RLS    │
└─────────────────────┘      └──────────────────────┘
```

- **前端**：纯静态HTML，部署在GitHub Pages（免费）
- **后端**：Supabase提供数据库、认证、API（免费tier足够5-10人使用）
- **登录**：Magic Link邮件登录（输入邮箱→收到登录链接→点击即登录）

---

## 二、Supabase 项目创建（约10分钟）

### Step 1: 注册Supabase
1. 打开 https://supabase.com
2. 用GitHub账号登录（推荐）或邮箱注册
3. 创建新项目：
   - 项目名：`photon-intern-hub`
   - 数据库密码：设一个（记住）
   - Region：选 `Southeast Asia (Singapore)` 延迟最低
4. 等待项目创建完成（约2分钟）

### Step 2: 获取 API 凭证
1. 进入项目 → Settings → API
2. 复制两个值：
   - **Project URL**：形如 `https://xxxxx.supabase.co`
   - **anon public key**：形如 `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.xxxxx`

### Step 3: 运行数据库脚本
1. 进入 Supabase Dashboard → SQL Editor
2. 打开 `supabase_schema.sql` 文件内容
3. 全选粘贴到SQL编辑器
4. 点击 Run
5. 确认所有表和策略创建成功（无红色错误）

### Step 4: 配置邮件认证
1. 进入 Authentication → Providers
2. 确认 Email 已启用（默认就是启用的）
3. 进入 Authentication → URL Configuration
4. 设置 Site URL 为你的GitHub Pages地址：
   `https://yanlilyli.github.io/intern-onboarding/`
5. 添加 Redirect URLs：
   `https://yanlilyli.github.io/intern-onboarding/`

---

## 三、前端配置（约2分钟）

### Step 1: 填入凭证
打开 `index.html`，找到顶部的配置区：

```javascript
const SUPABASE_URL = 'YOUR_SUPABASE_URL';
const SUPABASE_ANON_KEY = 'YOUR_SUPABASE_ANON_KEY';
```

替换为你的实际值：

```javascript
const SUPABASE_URL = 'https://xxxxx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.xxxxx';
```

### Step 2: 推送到GitHub Pages
```bash
cd /path/to/intern-onboarding
cp output/multi-user/index.html ./index.html
git add .
git commit -m "upgrade: multi-user version"
git push origin main
```

---

## 四、添加用户

### 方式一：用户自行注册
1. 用户打开网站 → 输入邮箱 → 点击「发送登录链接」
2. 去邮箱点击Magic Link → 自动登录
3. 系统自动创建profile，默认角色为 `intern`

### 方式二：管理员手动设置角色
新用户注册后默认是intern。要改为mentor或leader：

1. 进入 Supabase Dashboard → Table Editor → profiles
2. 找到对应用户
3. 修改 `role` 字段为 `mentor` 或 `leader`
4. 如果是实习生，设置 `mentor_id` 为其导师的id
5. 设置 `direction` 为实习生的方向（如 `S美术泛校招`）

### 初始用户设置示例

| email | name | role | mentor_id | direction |
|-------|------|------|-----------|-----------|
| leader@example.com | 包包 | leader | null | null |
| mentor@example.com | 李岩 | mentor | null | null |
| intern@example.com | 玉鑫 | intern | (李岩的id) | S美术泛校招 |

### 为新实习生初始化入职清单
在SQL Editor中运行：
```sql
SELECT public.init_checklist_for_intern('实习生的UUID');
```
（UUID从profiles表中复制）

---

## 五、日常管理

### 添加新实习生
1. 让新实习生打开网站 → 邮箱登录
2. 在profiles表中设置 `mentor_id` 和 `direction`
3. 运行 `init_checklist_for_intern` 初始化清单

### 修改实习计划
- 导师登录 → 「我的实习生」tab → 选择实习生 → 设置/编辑计划

### 查看数据
- Leader登录 → Dashboard tab → 查看汇总数据和图表
- 可以导出CSV做进一步分析

### 导出所有数据
- Leader Dashboard → 「📥 导出CSV」按钮
- 或在Supabase Dashboard → Table Editor 中直接导出

---

## 六、常见问题

### Q: Magic Link邮件收不到？
- 检查垃圾邮件文件夹
- Supabase免费tier每小时限制4封邮件给同一地址
- 可以在 Authentication → Settings 中配置自定义SMTP

### Q: 登录后显示错误？
- 确认 `SUPABASE_URL` 和 `SUPABASE_ANON_KEY` 填写正确
- 确认数据库脚本已运行成功
- 确认 Redirect URL 配置正确

### Q: 如何删除测试数据？
- 在 Supabase Table Editor 中直接删除行
- 或运行SQL：`DELETE FROM candidates WHERE intern_id = 'xxx';`

### Q: 免费tier够用吗？
- Supabase免费tier：50k月活、500MB数据库、5GB带宽
- 对于5-10个实习生的团队完全够用
- 如果需要更多，可以升级到Pro（$25/月）

---

## 七、文件清单

| 文件 | 说明 |
|------|------|
| `index.html` | 前端主应用（部署到GitHub Pages） |
| `supabase_schema.sql` | 数据库初始化脚本（在Supabase SQL Editor中运行） |
| `README.md` | 本文档 |
