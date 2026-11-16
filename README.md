# Archi · Proyecto completo de las pantallas solicitadas

Web HTML/CSS/JavaScript para Visual Studio Code, adaptada a PC y móvil. Mantiene los recursos gráficos anteriores de Archi y añade las pantallas de las capturas: datos personales, direcciones, preferencias de pago, notificaciones, historial/detalle del pedido y confirmación de cierre de sesión. No incluye datos personales de las capturas como cuentas reales.

## 1. Ver primero las pantallas
1. Extrae TODO el ZIP. Abre `archi-pasteleria` en Visual Studio Code.
2. Terminal → Nuevo terminal:
   ```powershell
   py -m http.server 5500
   ```
3. Abre `http://127.0.0.1:5500/web/`.
4. Elige **Explorar demostración** o **Ver administrador de demostración**.

No necesitas Supabase para recorrer el diseño. La demostración guarda cambios en la sesión de esa pestaña y los recupera al volver a entrar en demostración. Cliente y administrador comparten esos datos de ejemplo para probar el recorrido completo; no es un sistema de usuarios reales. Si cierras la pestaña pueden perderse. No escribas información sensible en demostración.

Para probar de extremo a extremo: cliente → producto → carrito → continuar → enviar pedido → perfil → cerrar sesión → confirmar → administrador de demostración → cambiar estado y pago → perfil → cerrar sesión → cliente → notificaciones y mis pedidos.

## 2. Pantallas incluidas
- Carga, inicio de sesión, registro y recuperación de acceso (cuentas reales mediante Supabase).
- Inicio, categorías, catálogo con búsqueda y favoritos.
- Detalle del producto con porciones, tamaño, ingredientes configurables y selector de cantidad.
- Carrito, revisión de entrega/pago, envío y recibo del pedido.
- Perfil y datos personales: foto, nombre, correo, celular, DNI opcional, dirección, nacimiento y cambio de contraseña real.
- Mis direcciones: agregar, editar y eliminar.
- Métodos de pago: guardar preferencias de efectivo, Yape o referencia de tarjeta (solo últimos 4 dígitos).
- Notificaciones internas: actualizaciones de pedidos, abrir detalle y marcar como leídas.
- Mis pedidos: filtro por estado y detalle.
- Confirmación de cierre de sesión: aceptar o cancelar.
- Ayuda/contacto: dirección, horario y teléfono administrables.
- Administrador: dashboard, productos e imágenes, pedidos, pago manual, galería y datos del negocio.

## 3. Sección del inicio
**«Conoce el rincón donde nace lo dulce»**

En administrador → Galería del local puedes subir fotos JPG, PNG o WebP (hasta 2 MB), poner título/descripción, cambiar el orden y mostrarlas u ocultarlas. Las fotos visibles aparecen en el inicio y se pueden ampliar.

La galería comienza vacía porque no se proporcionaron fotografías reales del local. No se inventaron ambientes de Archi. Los archivos de la galería son públicos: no subas documentos de clientes. Ocultar o eliminar la ficha la retira de la página, pero una URL pública previamente compartida puede seguir existiendo en Storage. Para eliminar definitivamente el archivo, el propietario debe borrarlo desde Storage.

## 4. Actualizar Supabase SI YA instalaste la versión anterior
1. Conserva una copia de tu proyecto anterior y de `web/config.js`.
2. En el proyecto Supabase de **Archi**, abre SQL Editor.
3. Ejecuta solo `supabase/migrations/20261115000100_pagina_completa.sql`, completo, una vez.
4. Reemplaza los archivos de la web con esta versión, conservando tus valores de `config.js`.
5. Recarga con Ctrl+F5.

No vuelvas a ejecutar la migración inicial en una base ya instalada. La segunda añade tablas y columnas y conserva los registros existentes. Si aparece un error, conserva el mensaje y detente; ambas migraciones están dentro de transacciones.

## 5. Instalar Supabase DESDE CERO
1. Crea un proyecto nuevo de Archi, separado de MAPO y de la antigua base MySQL.
2. En SQL Editor ejecuta una vez, en este orden:
   - `supabase/migrations/20261105000100_archi.sql`
   - `supabase/migrations/20261115000100_pagina_completa.sql`
3. En `web/config.js` pega Project URL y Publishable key:
   ```javascript
   window.ARCHI_CONFIG = {
     url: 'https://TU_REFERENCIA.supabase.co',
     key: 'sb_publishable_TU_CLAVE'
   };
   ```
   No uses contraseñas de base, secret keys ni service_role en la web.
4. Habilita correo y contraseña en Authentication. Mantén confirmación de correo. Configura SMTP propio para enviar correos a usuarios fuera del equipo del proyecto si el servicio predeterminado no permite esos destinatarios.
5. En Authentication → URL Configuration configura para pruebas:
   - Site URL: `http://127.0.0.1:5500/web/`
   - Redirect URLs: `http://127.0.0.1:5500/web/`
6. Abre la web y crea una cuenta con correo y contraseña de al menos 10 caracteres. Confirma el correo cuando se solicite.
7. Abre `operacion/primer_administrador.sql`, cambia el correo por tu cuenta confirmada y ejecútalo desde SQL Editor como propietario.
8. Cierra sesión y vuelve a entrar: la cuenta autorizada tendrá el panel administrativo.

## 6. Configuración del administrador antes de recibir pedidos
En **Datos del negocio y entrega** completa:
- Dirección real, horario y teléfono de la pastelería.
- Número y titular de Yape si se va a aceptar; vacío lo deshabilita.
- Entrega a domicilio y costo fijo. Está deshabilitada inicialmente.

Luego revisa productos/precios, porciones, tamaño e ingredientes; los textos vacíos aparecen como «Consultar». Oculta productos que no vendas. Carga las fotos reales del local en Galería.

Los pedidos comienzan como **pendientes de confirmación**, no como preparados ni pagados. El administrador puede confirmar, preparar, marcar listo, en camino, entregado o cancelado y validar el pago. El cliente recibe una notificación dentro de la web al cambiar estado o pago. La lista se actualiza al volver a abrirla; no hay notificaciones push fuera de la página.

## 7. Pagos y entrega: alcance real
- Efectivo y Yape se registran como métodos; el administrador verifica el dinero recibido.
- La referencia de tarjeta guarda solo los últimos 4 dígitos y una etiqueta. No se puede usar para cobrar en el checkout.
- No existe integración bancaria, cargo automático, pasarela de tarjetas ni verificación automática de Yape.
- El recibo es un detalle interno del pedido, no un comprobante fiscal.
- La entrega usa un costo fijo configurable y queda sujeta a la confirmación de cobertura del administrador. No incluye mapas ni seguimiento GPS.
- El gráfico agrupa pedidos pagados por mes de creación del pedido, no por fecha bancaria del cobro.
- No incluye inventario de ingredientes, proveedores ni facturación electrónica.

## 8. GitHub Pages
El workflow manual `.github/workflows/publicar.yml` publica solamente `web/`.

Si ya tienes el repositorio de Archi, copia los archivos actualizados conservando tu configuración y usa:
```powershell
git add .
git commit -m "Archi: pantallas completas y galeria administrable"
git push
```
En GitHub, configura Pages con GitHub Actions y ejecuta **Actions → Publicar portal Archi → Run workflow**. Agrega la URL final exacta de Pages a Site URL y Redirect URLs de Supabase. Al publicarse `web/` como raíz, la URL de producción no lleva `/web/` al final.

Si todavía no tienes repositorio, créalo vacío y sigue los pasos de GitHub para subir una carpeta existente. Este ZIP no crea un repositorio en tu cuenta ni cambia tus credenciales.

## 9. Archivos para modificar
- `web/index.html`: estructura inicial.
- `web/styles.css`: estilos de la versión anterior.
- `web/script.js`: lógica base.
- `web/complete.js`: nuevas pantallas, datos y administración.
- `web/complete.css`: diseño crema/naranja, tarjetas, navegación, transiciones y móvil.
- `web/config.js`: conexión pública.
- `supabase/migrations`: instalación inicial y actualización.
- `pruebas`: pruebas SQL locales reproducibles.

## 10. Validación realizada y pendiente
**Realizada:** sintaxis JavaScript; migraciones en PostgreSQL embebido (PGlite); aislamiento de perfiles/direcciones/pedidos/notificaciones entre dos clientes; bloqueo de cambios de roles, productos, totales y pagos por clientes; administrador autorizado; cálculo del total/envío en servidor; cantidades inválidas y dirección ajena rechazadas; reintento idempotente; notificaciones por pedido.

En navegador se verificaron demostración, perfil, agregar dirección, catálogo/detalle, carrito, envío de pedido, recibo, notificaciones, cierre de sesión, administrador y cambio de estado. La prueba del selector de archivos del navegador se interrumpió por un reinicio de la sesión de pruebas y no se da por validada.

**Pendiente en tu proyecto real:** ejecutar la migración, confirmar registro/correos/recuperación de contraseña, probar subida/lectura de fotos en Supabase Storage y revisar en tus dispositivos. Las pruebas locales simulan auth.uid y el esquema de Storage: no sustituyen la prueba del servicio remoto. No se ha conectado tu Supabase ni publicado en tu GitHub desde esta entrega.
