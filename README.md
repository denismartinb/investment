# Investment Atlas on Vercel

## Qué incluye

- `investment_dashboard.html`: dashboard estático que llama a la API privada para cargar Google Sheets.
- `api/portfolio.js`: función serverless que lee tu Google Sheet privada.
- `vercel.json`: hace que `/` sirva el dashboard.
- `local_server.js`: servidor local para probar el mismo flujo antes de desplegar.

## Despliegue en GitHub + Vercel

1. Crea un repositorio vacío en GitHub.
2. Desde esta carpeta, sube el proyecto:

```bash
git init
git add .
git commit -m "Initial investment dashboard"
git branch -M main
git remote add origin https://github.com/TU_USUARIO/TU_REPO.git
git push -u origin main
```

3. Entra en [Vercel](https://vercel.com/), pulsa `Add New -> Project` e importa ese repositorio.
4. En `Environment Variables` añade las variables indicadas abajo.
5. Pulsa `Deploy`.

## Variables de entorno de Vercel

Debes configurar estas variables en el proyecto de Vercel:

- `GOOGLE_SHEETS_SPREADSHEET_ID=1e-BwvxR5xz_aWPnVfSNW1PTAaAU-EXoNQvjFiwehCWg`
- `GOOGLE_SHEETS_SHEET_NAME=Data`
- `GOOGLE_SHEETS_RANGE` (opcional)
- `GOOGLE_SHEETS_PLAN_SHEET_NAME=Plan aportaciones`
- `GOOGLE_SHEETS_PLAN_RANGE='Plan aportaciones'!A:ZZ`
- `GOOGLE_SERVICE_ACCOUNT_EMAIL`
- `GOOGLE_SERVICE_ACCOUNT_PRIVATE_KEY`

## Cómo conectarlo a tu Google Sheet privada

1. Crea una service account en Google Cloud.
2. Activa Google Sheets API en ese proyecto.
3. Comparte tu Google Sheet con el email de la service account como `Viewer`.
4. Pega las variables anteriores en Vercel.

Importante:

- no subas el JSON descargado de la service account a GitHub
- pega solo `client_email` y `private_key` en Vercel
- como esa clave pasó por el chat, te conviene rotarla en Google Cloud antes de publicar

## Desarrollo local

```bash
npm run local
```

Luego abre `http://127.0.0.1:3001`. En ese modo, el dashboard ya lee directamente la Google Sheet privada desde la API local.

Si prefieres simular Vercel:

```bash
npx vercel dev
```

## Checklist antes de hacer push

- `.env.local` no debe subirse
- `investment-304214-0ce384847edb.json` no debe subirse
- el dashboard local debe funcionar en `http://127.0.0.1:3001`
- en Vercel debes ver `/api/portfolio` responder sin error
- si cambias la hoja, el botón `Actualizar datos` debe refrescar el dashboard

## Estructura esperada de la hoja

La primera fila debe contener estas cabeceras:

- `Nombre`
- `Fecha`
- `Tipo Inversión`
- `Participaciones`
- `Precio Participación`
- `Valor`
- `Aportación`
- `Beneficio`
- `TER`
- `ISIN`

Las fechas pueden estar como `dd/mm/yyyy` o `yyyy-mm-dd`.
