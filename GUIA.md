# 🚀 PeopleFlow HRMS — Guía de Implementación MVP

## Estructura del proyecto

```
peopleflow/
├── index.html       ← Landing page pública
├── login.html       ← Pantalla de autenticación
├── app.html         ← Dashboard principal (tu prototipo + Supabase)
├── database.sql     ← SQL para crear tablas en Supabase
└── vercel.json      ← Configuración de rutas para Vercel
```

---

## PASO 1 — Crear proyecto en Supabase (5 min)

1. Ve a **https://supabase.com** → "Start your project" → cuenta gratuita con GitHub
2. Clic en **"New Project"**
   - Name: `peopleflow`
   - Database Password: guárdala en algún lugar seguro
   - Region: `South America (São Paulo)` ← más cercana a Colombia
3. Espera ~2 minutos a que el proyecto cargue

### Obtener tus credenciales

1. En el panel de Supabase → **Settings** (engranaje) → **API**
2. Copia:
   - **Project URL**: `https://xxxxxxxxxxxx.supabase.co`
   - **anon public key**: `eyJhbG...` (la clave larga)

---

## PASO 2 — Crear las tablas (3 min)

1. En Supabase → **SQL Editor** → **New Query**
2. Pega todo el contenido del archivo `database.sql`
3. Clic en **"Run"** (o Ctrl+Enter)
4. Deberías ver: `Success. No rows returned`

---

## PASO 3 — Configurar credenciales en el código (2 min)

Abre **`login.html`** y **`app.html`** y reemplaza estas dos líneas:

```javascript
// ANTES (ambos archivos):
const SUPABASE_URL      = 'https://TU_PROYECTO.supabase.co';
const SUPABASE_ANON_KEY = 'TU_ANON_KEY';

// DESPUÉS (reemplaza con tus valores reales):
const SUPABASE_URL      = 'https://abcdefghijk.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...';
```

---

## PASO 4 — Crear tu primer usuario administrador (5 min)

### 4a. Crear usuario en Supabase Auth

1. Supabase → **Authentication** → **Users** → **"Add user"**
2. Ingresa:
   - Email: `tu@email.com`
   - Password: `contraseñaSegura123`
   - ✅ Auto Confirm User (marcar esto)
3. Clic **"Create user"**

### 4b. Asignar empresa al usuario

1. Supabase → **SQL Editor** → **New Query**
2. Ejecuta esto (reemplaza el email):

```sql
UPDATE public.users
SET
  company_id = 'aaaaaaaa-0000-0000-0000-000000000001',
  role       = 'admin',
  full_name  = 'Tu Nombre Aquí'
WHERE email = 'tu@email.com';
```

---

## PASO 5 — Deploy en Vercel (5 min)

### Opción A: Subir carpeta directamente (más simple)

1. Ve a **https://vercel.com** → cuenta gratuita con GitHub
2. Clic en **"Add New Project"** → **"Browse"**
3. Arrastra la carpeta `peopleflow/` completa
4. Clic **"Deploy"**
5. En ~30 segundos tendrás una URL pública como:  
   `https://peopleflow-xxxx.vercel.app`

### Opción B: Desde GitHub (recomendado para actualizaciones fáciles)

```bash
# 1. Sube a GitHub
git init
git add .
git commit -m "PeopleFlow MVP inicial"
git remote add origin https://github.com/TUUSUARIO/peopleflow.git
git push -u origin main

# 2. En Vercel → "Import Git Repository" → selecciona el repo
# 3. Deploy automático. Cada `git push` actualiza la app.
```

---

## PASO 6 — Registrar una segunda empresa cliente (para el SaaS)

```sql
-- 1. Crear la empresa
INSERT INTO public.companies (id, name, nit, plan)
VALUES (
  gen_random_uuid(),
  'Nombre del Cliente S.A.S.',
  '900999999-1',
  'pro'
);

-- 2. Verificar el ID asignado
SELECT id, name FROM public.companies ORDER BY created_at DESC LIMIT 1;
```

Luego en Supabase Auth → Add user → crea el usuario del cliente.

Finalmente asigna la empresa:
```sql
UPDATE public.users
SET company_id = 'EL-UUID-DE-SU-EMPRESA', role = 'admin', full_name = 'Nombre del Cliente'
WHERE email = 'cliente@empresa.com';
```

---

## Flujo completo del sistema

```
Usuario → index.html (landing)
       → login.html  (ingresa email + contraseña)
       → Supabase verifica credenciales
       → app.html carga
       → lee company_id del perfil del usuario
       → consulta employees WHERE company_id = ...
       → muestra SOLO los datos de SU empresa ✅
```

---

## Agregar más empleados vía código

```javascript
// Ejemplo: agregar empleado desde el dashboard
async function addEmployee(companyId, data) {
  const { data: employee, error } = await supabase
    .from('employees')
    .insert({
      company_id:    companyId,
      name:          data.name,
      email:         data.email,
      position:      data.position,
      department:    data.department,
      hire_date:     data.hireDate,
      salary:        data.salary,
      status:        'active'
    })
    .select()
    .single();

  if (error) throw error;
  return employee;
}
```

---

## Consultas útiles para el dashboard

```javascript
// Total empleados activos de mi empresa
const { count } = await supabase
  .from('employees')
  .select('*', { count: 'exact', head: true })
  .eq('company_id', myCompanyId)
  .eq('status', 'active');

// Empleados por departamento
const { data } = await supabase
  .from('employees')
  .select('department')
  .eq('company_id', myCompanyId);

// Buscar empleado por nombre
const { data } = await supabase
  .from('employees')
  .select('*')
  .eq('company_id', myCompanyId)
  .ilike('name', '%juan%');
```

---

## Costos — Todo GRATIS para el MVP

| Servicio | Plan gratuito | Límite |
|----------|--------------|--------|
| Supabase | Free tier | 500 MB DB, 50K usuarios auth |
| Vercel | Hobby | Ancho de banda ilimitado, proyectos ilimitados |
| GitHub | Free | Repositorios privados |

**Costo inicial: $0 COP** ✅

Cuando tengas 3-5 empresas cliente pagando, puedes escalar a:
- Supabase Pro: $25 USD/mes (8 GB DB, sin límite de usuarios)
- Vercel Pro: $20 USD/mes (si necesitas más funciones)

---

## Próximos pasos para el producto

1. **Formulario agregar empleado** — modal con formulario conectado a Supabase
2. **Módulo de nómina real** — cálculo automático con tabla payroll_runs
3. **Exportar a Excel/PDF** — usando SheetJS o jsPDF
4. **Email de bienvenida** — Supabase tiene email templates integrados
5. **Dominio propio** — en Vercel → Settings → Domains → agrega `app.peopleflow.co`
