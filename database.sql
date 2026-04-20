-- ═══════════════════════════════════════════════════════════════════
--  PeopleFlow HRMS · Schema SQL para Supabase
--  Ejecuta todo esto en: Supabase → SQL Editor → New Query → Run
-- ═══════════════════════════════════════════════════════════════════


-- ─────────────────────────────────────────────────────────────────
--  1. TABLA: companies (empresas tenant)
-- ─────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.companies (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name        TEXT NOT NULL,
  nit         TEXT UNIQUE,
  plan        TEXT DEFAULT 'starter' CHECK (plan IN ('starter','pro','enterprise')),
  is_active   BOOLEAN DEFAULT true,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- ─────────────────────────────────────────────────────────────────
--  2. TABLA: users (perfil extendido del usuario)
--     Nota: la autenticación la maneja supabase.auth.users
--           esta tabla guarda el perfil adicional y company_id
-- ─────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.users (
  id          UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email       TEXT,
  full_name   TEXT,
  company_id  UUID REFERENCES public.companies(id) ON DELETE SET NULL,
  role        TEXT DEFAULT 'user' CHECK (role IN ('superadmin','admin','user','readonly')),
  is_active   BOOLEAN DEFAULT true,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- ─────────────────────────────────────────────────────────────────
--  3. TABLA: employees (empleados por empresa)
-- ─────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.employees (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id      UUID NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
  name            TEXT NOT NULL,
  email           TEXT,
  position        TEXT,
  department      TEXT,
  contract_type   TEXT DEFAULT 'Indefinido',
  hire_date       DATE,
  salary          NUMERIC(12,2),
  status          TEXT DEFAULT 'active' CHECK (status IN ('active','inactive','pending')),
  phone           TEXT,
  document_id     TEXT,        -- Cédula / NIT del empleado
  address         TEXT,
  notes           TEXT,
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ─────────────────────────────────────────────────────────────────
--  4. TABLA: payroll_runs (ejecuciones de nómina)
-- ─────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.payroll_runs (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id      UUID NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
  period_label    TEXT NOT NULL,          -- ej: "Mayo 2025"
  period_start    DATE NOT NULL,
  period_end      DATE NOT NULL,
  total_amount    NUMERIC(14,2),
  status          TEXT DEFAULT 'draft' CHECK (status IN ('draft','processing','paid','cancelled')),
  processed_by    UUID REFERENCES public.users(id),
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ─────────────────────────────────────────────────────────────────
--  5. TABLA: attendance (registros de asistencia)
-- ─────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.attendance (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id      UUID NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
  employee_id     UUID NOT NULL REFERENCES public.employees(id) ON DELETE CASCADE,
  date            DATE NOT NULL,
  check_in        TIME,
  check_out       TIME,
  status          TEXT DEFAULT 'present' CHECK (status IN ('present','absent','late','holiday','permission')),
  notes           TEXT,
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(employee_id, date)
);

-- ─────────────────────────────────────────────────────────────────
--  6. TRIGGER: sincronizar email desde auth.users al crear usuario
-- ─────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  INSERT INTO public.users (id, email)
  VALUES (NEW.id, NEW.email)
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ─────────────────────────────────────────────────────────────────
--  7. ROW LEVEL SECURITY (RLS) — Seguridad Multiempresa
--     Cada usuario solo ve los datos de SU empresa
-- ─────────────────────────────────────────────────────────────────

-- Habilitar RLS en todas las tablas
ALTER TABLE public.companies  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.users      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.employees  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payroll_runs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.attendance ENABLE ROW LEVEL SECURITY;

-- ── Función auxiliar: obtener company_id del usuario actual ──
CREATE OR REPLACE FUNCTION public.my_company_id()
RETURNS UUID LANGUAGE sql STABLE AS $$
  SELECT company_id FROM public.users WHERE id = auth.uid();
$$;

-- ── Políticas: companies ──
CREATE POLICY "users_see_own_company" ON public.companies
  FOR SELECT USING (id = public.my_company_id());

-- ── Políticas: users ──
CREATE POLICY "users_see_own_profile" ON public.users
  FOR SELECT USING (id = auth.uid() OR company_id = public.my_company_id());

CREATE POLICY "users_update_own_profile" ON public.users
  FOR UPDATE USING (id = auth.uid());

-- ── Políticas: employees ──
CREATE POLICY "employees_company_select" ON public.employees
  FOR SELECT USING (company_id = public.my_company_id());

CREATE POLICY "employees_company_insert" ON public.employees
  FOR INSERT WITH CHECK (company_id = public.my_company_id());

CREATE POLICY "employees_company_update" ON public.employees
  FOR UPDATE USING (company_id = public.my_company_id());

CREATE POLICY "employees_company_delete" ON public.employees
  FOR DELETE USING (company_id = public.my_company_id());

-- ── Políticas: payroll_runs ──
CREATE POLICY "payroll_company_select" ON public.payroll_runs
  FOR SELECT USING (company_id = public.my_company_id());

CREATE POLICY "payroll_company_insert" ON public.payroll_runs
  FOR INSERT WITH CHECK (company_id = public.my_company_id());

-- ── Políticas: attendance ──
CREATE POLICY "attendance_company_select" ON public.attendance
  FOR SELECT USING (company_id = public.my_company_id());

CREATE POLICY "attendance_company_insert" ON public.attendance
  FOR INSERT WITH CHECK (company_id = public.my_company_id());

-- ─────────────────────────────────────────────────────────────────
--  8. DATOS DE PRUEBA (ejecuta esto DESPUÉS de lo anterior)
-- ─────────────────────────────────────────────────────────────────

-- Insertar empresa de prueba
INSERT INTO public.companies (id, name, nit, plan)
VALUES (
  'aaaaaaaa-0000-0000-0000-000000000001',
  'TechCorp S.A.S.',
  '900123456-7',
  'enterprise'
) ON CONFLICT DO NOTHING;

-- Insertar empleados de prueba para esa empresa
INSERT INTO public.employees (company_id, name, email, position, department, contract_type, hire_date, salary, status)
VALUES
  ('aaaaaaaa-0000-0000-0000-000000000001', 'Ana Sofía Restrepo', 'ana@techcorp.co', 'Dir. RRHH', 'RRHH', 'Indefinido', '2019-03-15', 8500000, 'active'),
  ('aaaaaaaa-0000-0000-0000-000000000001', 'Pedro Mora', 'pedro@techcorp.co', 'Dir. Tecnología', 'Tecnología', 'Indefinido', '2018-01-02', 10200000, 'active'),
  ('aaaaaaaa-0000-0000-0000-000000000001', 'Laura Vargas', 'laura@techcorp.co', 'Dir. Comercial', 'Comercial', 'Indefinido', '2020-05-10', 9800000, 'active'),
  ('aaaaaaaa-0000-0000-0000-000000000001', 'Juan Ospina', 'juan@techcorp.co', 'Dir. Finanzas', 'Finanzas', 'Indefinido', '2021-02-01', 9200000, 'active'),
  ('aaaaaaaa-0000-0000-0000-000000000001', 'David Mora', 'david@techcorp.co', 'Dev Senior', 'Tecnología', 'Indefinido', '2021-06-05', 6800000, 'active'),
  ('aaaaaaaa-0000-0000-0000-000000000001', 'Juliana Ríos', 'juliana@techcorp.co', 'Analista Ventas', 'Comercial', 'Término Fijo', '2023-03-01', 3200000, 'active'),
  ('aaaaaaaa-0000-0000-0000-000000000001', 'Carlos Pacheco', 'carlos@techcorp.co', 'Oper. Logística', 'Operaciones', 'Término Fijo', '2022-09-15', 2800000, 'inactive'),
  ('aaaaaaaa-0000-0000-0000-000000000001', 'Sofía Bermúdez', 'sofia@techcorp.co', 'Diseñadora Gráfica', 'Marketing', 'Prestación Serv.', '2024-01-20', 3500000, 'pending'),
  ('aaaaaaaa-0000-0000-0000-000000000001', 'Andrés Castro', 'andres@techcorp.co', 'Dev Frontend', 'Tecnología', 'Indefinido', '2022-11-08', 5400000, 'active'),
  ('aaaaaaaa-0000-0000-0000-000000000001', 'María F. López', 'maria@techcorp.co', 'Diseñadora UX', 'Tecnología', 'Indefinido', '2025-05-27', 5800000, 'pending')
ON CONFLICT DO NOTHING;

-- ─────────────────────────────────────────────────────────────────
--  9. ASIGNAR EMPRESA A UN USUARIO EXISTENTE
--     (Ejecuta esto DESPUÉS de crear el usuario desde Supabase Auth)
--     Reemplaza 'EMAIL_DEL_USUARIO' con el email real
-- ─────────────────────────────────────────────────────────────────

/*
UPDATE public.users
SET
  company_id = 'aaaaaaaa-0000-0000-0000-000000000001',
  role       = 'admin',
  full_name  = 'Tu Nombre Aquí'
WHERE email = 'EMAIL_DEL_USUARIO@dominio.com';
*/

-- ─────────────────────────────────────────────────────────────────
--  10. VERIFICAR QUE TODO ESTÁ CORRECTO
-- ─────────────────────────────────────────────────────────────────
-- SELECT * FROM public.companies;
-- SELECT * FROM public.users;
-- SELECT * FROM public.employees WHERE company_id = 'aaaaaaaa-0000-0000-0000-000000000001';

-- ─────────────────────────────────────────────────────────────────
--  11. POLÍTICA SUPERADMIN — acceso total para admin del SaaS
-- ─────────────────────────────────────────────────────────────────
-- Función: verificar si el usuario actual es superadmin
CREATE OR REPLACE FUNCTION public.is_superadmin()
RETURNS BOOLEAN LANGUAGE sql STABLE AS $$
  SELECT EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'superadmin');
$$;

-- Dar acceso superadmin a companies (ver todas)
CREATE POLICY "superadmin_companies_all" ON public.companies
  FOR ALL USING (public.is_superadmin());

-- Dar acceso superadmin a users (ver todos)
CREATE POLICY "superadmin_users_all" ON public.users
  FOR ALL USING (public.is_superadmin());

-- Dar acceso superadmin a employees (ver todos)
CREATE POLICY "superadmin_employees_all" ON public.employees
  FOR ALL USING (public.is_superadmin());

-- ─────────────────────────────────────────────────────────────────
--  12. CREAR TU CUENTA SUPERADMIN
--      (Después de crear tu usuario en Supabase Auth y que
--       el trigger lo haya insertado en public.users)
-- ─────────────────────────────────────────────────────────────────
/*
UPDATE public.users
SET role = 'superadmin', full_name = 'Tu Nombre'
WHERE email = 'tu_email_de_admin@dominio.com';
*/

-- ─────────────────────────────────────────────────────────────────
--  13. ÍNDICES para mejor rendimiento
-- ─────────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_employees_company_id ON public.employees(company_id);
CREATE INDEX IF NOT EXISTS idx_employees_status ON public.employees(status);
CREATE INDEX IF NOT EXISTS idx_users_company_id ON public.users(company_id);
CREATE INDEX IF NOT EXISTS idx_attendance_employee_date ON public.attendance(employee_id, date);
