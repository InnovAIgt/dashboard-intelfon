-- ============================================
-- SETUP SUPABASE: RED INTELFON REPORTES
-- ============================================
-- Ejecuta este script en: https://app.supabase.com/project/[PROJECT_ID]/sql/new
-- 1. Copia TODO el contenido
-- 2. Pégalo en el editor SQL de Supabase
-- 3. Presiona "Run" (o Ctrl+Enter)

-- ============================================
-- TABLA: LEADS (Prospectiva)
-- ============================================
CREATE TABLE IF NOT EXISTS leads (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    nombre TEXT NOT NULL,
    email TEXT,
    telefono TEXT,
    empresa TEXT,
    estado TEXT DEFAULT 'nuevo',
    origen TEXT,
    descripcion TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()),
    CONSTRAINT leads_email_check CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}$' OR email IS NULL)
);

-- Índices para optimizar búsquedas
CREATE INDEX IF NOT EXISTS idx_leads_created_at ON leads(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_leads_email ON leads(email);
CREATE INDEX IF NOT EXISTS idx_leads_telefono ON leads(telefono);
CREATE INDEX IF NOT EXISTS idx_leads_estado ON leads(estado);
CREATE INDEX IF NOT EXISTS idx_leads_empresa ON leads(empresa);

-- Trigger para actualizar updated_at automáticamente
CREATE OR REPLACE FUNCTION update_leads_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = TIMEZONE('utc'::text, NOW());
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS leads_update_timestamp ON leads;
CREATE TRIGGER leads_update_timestamp
    BEFORE UPDATE ON leads
    FOR EACH ROW
    EXECUTE FUNCTION update_leads_timestamp();

-- ============================================
-- TABLA: HISTORIALES (Seguimiento)
-- ============================================
CREATE TABLE IF NOT EXISTS historiales (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    lead_id UUID REFERENCES leads(id) ON DELETE CASCADE,
    tipo_actividad TEXT NOT NULL,
    descripcion TEXT,
    resultado TEXT,
    fecha_seguimiento TIMESTAMP WITH TIME ZONE,
    notas TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW())
);

-- Índices para historiales
CREATE INDEX IF NOT EXISTS idx_historiales_created_at ON historiales(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_historiales_lead_id ON historiales(lead_id);
CREATE INDEX IF NOT EXISTS idx_historiales_tipo_actividad ON historiales(tipo_actividad);
CREATE INDEX IF NOT EXISTS idx_historiales_fecha_seguimiento ON historiales(fecha_seguimiento);

-- Trigger para historiales
CREATE OR REPLACE FUNCTION update_historiales_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = TIMEZONE('utc'::text, NOW());
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS historiales_update_timestamp ON historiales;
CREATE TRIGGER historiales_update_timestamp
    BEFORE UPDATE ON historiales
    FOR EACH ROW
    EXECUTE FUNCTION update_historiales_timestamp();

-- ============================================
-- TABLA: LLAMADAS (Registro de Llamadas)
-- ============================================
CREATE TABLE IF NOT EXISTS llamadas (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    lead_id UUID REFERENCES leads(id) ON DELETE CASCADE,
    numero_marcado TEXT NOT NULL,
    numero_origen TEXT,
    duracion_segundos INTEGER DEFAULT 0,
    estado_llamada TEXT,
    grabacion_url TEXT,
    transcripcion TEXT,
    resultado TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW())
);

-- Índices para llamadas
CREATE INDEX IF NOT EXISTS idx_llamadas_created_at ON llamadas(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_llamadas_lead_id ON llamadas(lead_id);
CREATE INDEX IF NOT EXISTS idx_llamadas_numero_marcado ON llamadas(numero_marcado);
CREATE INDEX IF NOT EXISTS idx_llamadas_estado_llamada ON llamadas(estado_llamada);

-- Trigger para llamadas
CREATE OR REPLACE FUNCTION update_llamadas_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = TIMEZONE('utc'::text, NOW());
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS llamadas_update_timestamp ON llamadas;
CREATE TRIGGER llamadas_update_timestamp
    BEFORE UPDATE ON llamadas
    FOR EACH ROW
    EXECUTE FUNCTION update_llamadas_timestamp();

-- ============================================
-- POLÍTICAS RLS (Row Level Security)
-- ============================================
-- Habilitar RLS
ALTER TABLE leads ENABLE ROW LEVEL SECURITY;
ALTER TABLE historiales ENABLE ROW LEVEL SECURITY;
ALTER TABLE llamadas ENABLE ROW LEVEL SECURITY;

-- Políticas permitidas para anon key (lee todo, sin escribir)
CREATE POLICY "Permitir lectura pública leads" ON leads
    FOR SELECT USING (true);

CREATE POLICY "Permitir lectura pública historiales" ON historiales
    FOR SELECT USING (true);

CREATE POLICY "Permitir lectura pública llamadas" ON llamadas
    FOR SELECT USING (true);

-- Si necesitas escritura desde el frontend (opcional), descomentar:
-- CREATE POLICY "Permitir inserción leads" ON leads
--     FOR INSERT WITH CHECK (true);

-- ============================================
-- VISTAS ÚTILES
-- ============================================
CREATE OR REPLACE VIEW leads_activos AS
SELECT 
    l.id,
    l.nombre,
    l.email,
    l.telefono,
    l.empresa,
    l.estado,
    COUNT(h.id) as total_historiales,
    COUNT(ll.id) as total_llamadas,
    MAX(h.created_at) as ultimo_seguimiento,
    MAX(ll.created_at) as ultima_llamada,
    l.created_at
FROM leads l
LEFT JOIN historiales h ON l.id = h.lead_id
LEFT JOIN llamadas ll ON l.id = ll.lead_id
WHERE l.created_at >= CURRENT_DATE - INTERVAL '90 days'
GROUP BY l.id, l.nombre, l.email, l.telefono, l.empresa, l.estado, l.created_at
ORDER BY l.created_at DESC;

-- Vista de resumen por día
CREATE OR REPLACE VIEW resumen_diario AS
SELECT 
    DATE(created_at) as fecha,
    COUNT(DISTINCT id) as total_leads,
    COUNT(DISTINCT CASE WHEN estado = 'nuevo' THEN id END) as leads_nuevos,
    COUNT(DISTINCT CASE WHEN estado = 'contactado' THEN id END) as leads_contactados,
    COUNT(DISTINCT CASE WHEN estado = 'cerrado' THEN id END) as leads_cerrados
FROM leads
WHERE created_at >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY DATE(created_at)
ORDER BY fecha DESC;

-- ============================================
-- INSERTS DE PRUEBA (OPCIONAL)
-- ============================================
-- Descomentar para agregar datos de prueba

-- INSERT INTO leads (nombre, email, telefono, empresa, estado, origen) VALUES
-- ('Juan Pérez', 'juan@example.com', '+503 7777-1234', 'Empresa A', 'nuevo', 'referencia'),
-- ('María García', 'maria@example.com', '+503 7777-5678', 'Empresa B', 'contactado', 'web'),
-- ('Carlos López', 'carlos@example.com', '+503 7777-9012', 'Empresa C', 'nuevo', 'llamada');

-- ============================================
-- NOTAS DE SEGURIDAD
-- ============================================
-- 1. Esta configuración usa RLS (Row Level Security)
-- 2. El anon_key solo puede LEER datos, no escribir
-- 3. Para escribir, necesitarías autenticación JWT
-- 4. Los datos desde el 1 de julio 2024 en adelante se cargan automáticamente
-- 5. Los índices optimizan las búsquedas por fecha y estado
-- 6. Los triggers mantienen actualizado el campo updated_at automáticamente

-- ============================================
-- COMANDO DE SOPORTE
-- ============================================
-- Para ver el tamaño de cada tabla:
-- SELECT 
--     schemaname,
--     tablename,
--     pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as tamaño
-- FROM pg_tables
-- WHERE schemaname = 'public'
-- ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
