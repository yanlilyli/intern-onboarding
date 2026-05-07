-- ============================================
-- 光子招聘实习生通关手册 · Supabase 数据库初始化脚本
-- ============================================
-- 使用方式：在 Supabase Dashboard → SQL Editor 中运行此脚本

-- 1. 用户档案表（扩展 auth.users）
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  name TEXT NOT NULL,
  role TEXT NOT NULL CHECK (role IN ('intern', 'mentor', 'leader')),
  mentor_id UUID REFERENCES public.profiles(id),
  direction TEXT, -- 实习生的方向：如 S美术泛校招/天玑美术社招/策划 等
  start_date DATE,
  end_date DATE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. 实习计划表（导师为实习生设置）
CREATE TABLE IF NOT EXISTS public.plans (
  id BIGSERIAL PRIMARY KEY,
  intern_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  phase TEXT, -- 阶段名
  week TEXT, -- W1, W2, W3-4 等
  goal TEXT,
  tasks TEXT,
  deliverables TEXT,
  notes TEXT,
  created_by UUID REFERENCES public.profiles(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. 每周Review表
CREATE TABLE IF NOT EXISTS public.reviews (
  id BIGSERIAL PRIMARY KEY,
  intern_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  week INTEGER NOT NULL, -- 1-24
  date_range TEXT, -- 如 5/11-5/15
  s_art_rec INTEGER DEFAULT 0, -- S美术泛校招推荐数
  s_art_iv INTEGER DEFAULT 0, -- S美术泛校招进面数
  tj_art_rec INTEGER DEFAULT 0, -- 天玑美术社招推荐数
  tj_art_iv INTEGER DEFAULT 0, -- 天玑美术社招进面数
  plan_rec INTEGER DEFAULT 0, -- 策划推荐数
  plan_iv INTEGER DEFAULT 0, -- 策划进面数
  tasks TEXT, -- 本周核心任务
  done TEXT, -- 完成情况
  next_plan TEXT, -- 下周计划
  issues TEXT, -- 问题&需要支持
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(intern_id, week)
);

-- 4. Sourcing Track 候选人表
CREATE TABLE IF NOT EXISTS public.candidates (
  id BIGSERIAL PRIMARY KEY,
  intern_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  name TEXT,
  direction TEXT, -- S美术泛校招/天玑美术社招/策划
  position TEXT, -- 岗位
  company TEXT, -- 公司
  channel TEXT, -- 渠道
  status TEXT DEFAULT '待触达' CHECK (status IN ('待触达','已触达','沟通中','已推荐','面试中','已offer','不合适','暂无意向')),
  recommend_date DATE,
  resume_link TEXT,
  comments TEXT,
  custom_fields JSONB DEFAULT '{}', -- 自定义字段
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5. 入职清单表
CREATE TABLE IF NOT EXISTS public.checklist (
  id BIGSERIAL PRIMARY KEY,
  intern_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  item_text TEXT NOT NULL,
  day TEXT, -- Day1, Day2...
  checked BOOLEAN DEFAULT FALSE,
  sort_order INTEGER DEFAULT 0,
  UNIQUE(intern_id, item_text)
);

-- ============================================
-- Row Level Security (RLS) 策略
-- ============================================

-- 开启 RLS
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.candidates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.checklist ENABLE ROW LEVEL SECURITY;

-- === profiles 策略 ===
-- 所有已登录用户可以读取profiles（用于显示名字等）
CREATE POLICY "profiles_read_all" ON public.profiles
  FOR SELECT USING (auth.uid() IS NOT NULL);

-- 用户只能更新自己的profile
CREATE POLICY "profiles_update_own" ON public.profiles
  FOR UPDATE USING (id = auth.uid());

-- === plans 策略 ===
-- 实习生看自己的计划
CREATE POLICY "plans_intern_read" ON public.plans
  FOR SELECT USING (intern_id = auth.uid());

-- 导师可以读写名下实习生的计划
CREATE POLICY "plans_mentor_read" ON public.plans
  FOR SELECT USING (
    intern_id IN (SELECT id FROM public.profiles WHERE mentor_id = auth.uid())
  );

CREATE POLICY "plans_mentor_write" ON public.plans
  FOR ALL USING (
    intern_id IN (SELECT id FROM public.profiles WHERE mentor_id = auth.uid())
  );

-- Leader可以读所有计划
CREATE POLICY "plans_leader_read" ON public.plans
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'leader')
  );

-- === reviews 策略 ===
-- 实习生读写自己的review
CREATE POLICY "reviews_intern_all" ON public.reviews
  FOR ALL USING (intern_id = auth.uid());

-- 导师读名下实习生的review
CREATE POLICY "reviews_mentor_read" ON public.reviews
  FOR SELECT USING (
    intern_id IN (SELECT id FROM public.profiles WHERE mentor_id = auth.uid())
  );

-- Leader读所有
CREATE POLICY "reviews_leader_read" ON public.reviews
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'leader')
  );

-- === candidates 策略 ===
-- 实习生读写自己的候选人
CREATE POLICY "candidates_intern_all" ON public.candidates
  FOR ALL USING (intern_id = auth.uid());

-- 导师读名下实习生的候选人
CREATE POLICY "candidates_mentor_read" ON public.candidates
  FOR SELECT USING (
    intern_id IN (SELECT id FROM public.profiles WHERE mentor_id = auth.uid())
  );

-- Leader读所有
CREATE POLICY "candidates_leader_read" ON public.candidates
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'leader')
  );

-- === checklist 策略 ===
-- 实习生读写自己的清单
CREATE POLICY "checklist_intern_all" ON public.checklist
  FOR ALL USING (intern_id = auth.uid());

-- 导师读名下实习生的清单
CREATE POLICY "checklist_mentor_read" ON public.checklist
  FOR SELECT USING (
    intern_id IN (SELECT id FROM public.profiles WHERE mentor_id = auth.uid())
  );

-- Leader读所有
CREATE POLICY "checklist_leader_read" ON public.checklist
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'leader')
  );

-- ============================================
-- 触发器：自动创建profile
-- ============================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, email, name, role)
  VALUES (NEW.id, NEW.email, COALESCE(NEW.raw_user_meta_data->>'name', split_part(NEW.email, '@', 1)), 'intern');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- ============================================
-- 初始化默认入职清单模板
-- ============================================
CREATE OR REPLACE FUNCTION public.init_checklist_for_intern(p_intern_id UUID)
RETURNS VOID AS $$
BEGIN
  INSERT INTO public.checklist (intern_id, item_text, day, sort_order) VALUES
    (p_intern_id, '入职手续办理完成', 'Day1', 1),
    (p_intern_id, '权限中台申请系统权限 + 文档权限', 'Day1', 2),
    (p_intern_id, '加入团队企微群', 'Day1', 3),
    (p_intern_id, '阅读在招岗位JD（能说出3个核心方向）', 'Day1', 4),
    (p_intern_id, '学习招聘系统基本操作', 'Day2', 5),
    (p_intern_id, 'Boss直聘企业账号配置完成', 'Day2', 6),
    (p_intern_id, '了解S工作室/天玑组织架构', 'Day2', 7),
    (p_intern_id, '开始sourcing实操，提交首批简历', 'Day3', 8),
    (p_intern_id, '跟听1场面试，记录观察笔记', 'Day4', 9),
    (p_intern_id, '输出第一周周报', 'Day5', 10)
  ON CONFLICT (intern_id, item_text) DO NOTHING;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- 辅助视图：Leader Dashboard 数据汇总
-- ============================================
CREATE OR REPLACE VIEW public.dashboard_summary AS
SELECT
  p.id AS intern_id,
  p.name AS intern_name,
  p.direction,
  mp.name AS mentor_name,
  COUNT(c.id) AS total_candidates,
  COUNT(c.id) FILTER (WHERE c.status IN ('已推荐','面试中','已offer')) AS recommended,
  COUNT(c.id) FILTER (WHERE c.status = '面试中') AS interviewing,
  COUNT(c.id) FILTER (WHERE c.status = '已offer') AS offered,
  COUNT(c.id) FILTER (WHERE c.direction = 'S美术泛校招') AS s_art_total,
  COUNT(c.id) FILTER (WHERE c.direction = '天玑美术社招') AS tj_art_total,
  COUNT(c.id) FILTER (WHERE c.direction = '策划') AS plan_total,
  (SELECT COUNT(*) FROM public.reviews r WHERE r.intern_id = p.id AND r.done IS NOT NULL AND r.done != '') AS reviews_done
FROM public.profiles p
LEFT JOIN public.profiles mp ON p.mentor_id = mp.id
LEFT JOIN public.candidates c ON c.intern_id = p.id
WHERE p.role = 'intern'
GROUP BY p.id, p.name, p.direction, mp.name;
