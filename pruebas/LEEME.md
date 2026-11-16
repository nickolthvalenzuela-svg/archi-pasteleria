# Pruebas locales de datos y permisos
Desde la carpeta principal del proyecto, con Node.js:

```powershell
npm install --no-save @electric-sql/pglite
node pruebas/database.mjs
```

Se usa PostgreSQL embebido en memoria, sin conectar ni modificar Supabase real. Simula esquemas auth/storage mínimos para verificar las migraciones y permisos de tablas y funciones. No prueba el servicio de correo, el almacenamiento HTTP ni la subida de archivos.
