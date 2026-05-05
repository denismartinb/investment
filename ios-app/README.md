# iOS App

Base nativa SwiftUI para el dashboard privado de inversión.

## Enfoque recomendado

- `SwiftUI` para interfaz nativa y mantenimiento sencillo.
- `URLSession` + `HTTPCookieStorage` para reutilizar el login propio actual.
- `TestFlight` para distribución privada y actualizaciones iterativas.
- Mantener el backend actual en Vercel y consumir su API autenticada.

## Estructura

- `project.yml`: especificación del proyecto para XcodeGen.
- `InvestmentDashboardApp/`: código fuente principal.
- `InvestmentDashboardApp/Models`: modelos del payload del dashboard.
- `InvestmentDashboardApp/Services`: autenticación, configuración y cliente API.
- `InvestmentDashboardApp/ViewModels`: estado principal de la app.
- `InvestmentDashboardApp/Views`: pantallas SwiftUI.

## Recomendación práctica para ti

Como la app es solo para uso personal, la vía buena es:

1. app nativa SwiftUI
2. backend en Vercel con tu login propio
3. distribución por TestFlight

Así te quedas con:
- experiencia móvil mejor que la web
- control privado del acceso
- despliegue muy simple sin publicar en App Store

## Cómo abrirla

### Opción 1
Instala XcodeGen y genera el proyecto desde `project.yml`:

```bash
brew install xcodegen
cd ios-app
xcodegen generate
```

Luego abre `InvestmentDashboardApp.xcodeproj` en Xcode.

### Opción 2
Si prefieres no instalar nada, usa esta estructura como base y crea un proyecto iOS App en Xcode con el mismo nombre, copiando dentro la carpeta `InvestmentDashboardApp/`.

## Configuración necesaria

Antes de compilar, cambia en `InvestmentDashboardApp/Services/AppConfiguration.swift` la URL base para apuntar a tu backend:

- local: `http://127.0.0.1:3001`
- Vercel: tu URL protegida final

## Siguiente paso recomendado

1. generar el proyecto en Xcode
2. probar login real contra local/Vercel
3. añadir gráficos nativos
4. preparar firma y subir a TestFlight
