# Investment Atlas on Vercel

## Qué incluye

- `investment_dashboard.html`: dashboard estático protegido tras login.
- `login.html`: pantalla de acceso con usuario y contraseña.
- `api/dashboard.js`: entrega el dashboard solo si la sesión es válida.
- `api/portfolio.js`: función serverless que lee tu Google Sheet privada y ahora exige sesión.
- `api/auth/login.js` y `api/auth/logout.js`: inicio y cierre de sesión.
- `vercel.json`: enruta `/` al dashboard protegido y `/login` a la pantalla de acceso.
- `local_server.js`: servidor local para probar exactamente el mismo flujo antes de desplegar.

## Variables de entorno de Vercel

Debes configurar estas variables en el proyecto de Vercel:

- `GOOGLE_SHEETS_SPREADSHEET_ID=1e-BwvxR5xz_aWPnVfSNW1PTAaAU-EXoNQvjFiwehCWg`
- `GOOGLE_SHEETS_SHEET_NAME=Data`
- `GOOGLE_SHEETS_RANGE` (opcional)
- `GOOGLE_SHEETS_PLAN_SHEET_NAME=Plan aportaciones`
- `GOOGLE_SHEETS_PLAN_RANGE='Plan aportaciones'!A:ZZ`
- `GOOGLE_SERVICE_ACCOUNT_EMAIL`
- `GOOGLE_SERVICE_ACCOUNT_PRIVATE_KEY`
- `DASHBOARD_USERNAME`
- `DASHBOARD_PASSWORD`
- `DASHBOARD_AUTH_SECRET`

## Protección del dashboard

El acceso ya no depende de Vercel Authentication. Ahora el proyecto usa:

- login propio con `usuario + contraseña`
- cookie de sesión firmada
- protección tanto del HTML principal como de `/api/portfolio`

Recomendaciones:

- usa una `DASHBOARD_AUTH_SECRET` larga y aleatoria
- no reutilices tu contraseña de otros servicios
- rota la `GOOGLE_SERVICE_ACCOUNT_PRIVATE_KEY`, porque quedó expuesta durante esta conversación

## Desarrollo local

1. Añade en `.env.local` las variables de Google y también:
   - `DASHBOARD_USERNAME`
   - `DASHBOARD_PASSWORD`
   - `DASHBOARD_AUTH_SECRET`
2. Arranca:

```bash
npm run local
```

3. Abre `http://127.0.0.1:3001/login`

## Despliegue en GitHub + Vercel

1. Sube el proyecto al repo.
2. Importa el repo en Vercel.
3. Añade todas las variables de entorno anteriores.
4. Haz `Deploy`.

## Checklist antes de publicar

- `.env.local` no debe subirse
- `investment-304214-0ce384847edb.json` no debe subirse
- `DASHBOARD_PASSWORD` y `DASHBOARD_AUTH_SECRET` deben existir en Vercel
- el login debe funcionar en `/login`
- `/api/portfolio` debe devolver `401` sin sesión y `200` con sesión
