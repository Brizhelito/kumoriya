# Guía de publicación de Windows v0.4.0

## Estado actual

La base del proyecto Windows ya está lista para compilar:

- `apps/kumoriya_app/windows/CMakeLists.txt` existe y configura el build de Flutter para Windows.
- `apps/kumoriya_app/windows/runner/CMakeLists.txt` existe y define el ejecutable.
- `apps/kumoriya_app/windows/runner/Runner.rc` incluye el icono y la metadata de versión.
- `apps/kumoriya_app/windows/runner/resources/app_icon.ico` existe.
- `apps/kumoriya_app/windows/runner/runner.exe.manifest` existe.
- `apps/kumoriya_app/windows/kumoriya_installer.iss` existe y ya apunta al icono correcto.

## Lo que falta instalar en Windows

Como solo tienes Visual Studio, todavía necesitas esto para poder compilar y publicar la v0.4.0:

- **Flutter SDK**
  - Debe estar instalado y agregado al `PATH`.
  - Verifica con `flutter --version`.

- **Visual Studio 2022**
  - Ya lo tienes, pero asegúrate de tener instalado el workload:
    - **Desktop development with C++**
  - Y estos componentes comunes:
    - MSVC v143
    - Windows 10/11 SDK
    - CMake tools for Windows

- **Inno Setup**
  - Necesario para generar el instalador `.exe`.
  - El script usa `iscc`.
  - Verifica con `iscc /?`.

- **AWS CLI v2**
  - Necesario para subir el instalador a R2.
  - Verifica con `aws --version`.

- **PowerShell 7+ o Windows PowerShell 5+**
  - Para ejecutar el script de publicación.

## Firma del instalador

Ahora mismo el proyecto **no tiene** un certificado de firma configurado en el repo.

Eso significa:

- El instalador puede compilarse sin firma.
- Si quieres firma de código, necesitas un certificado `.pfx` válido y el comando `signtool`.
- No encontré en el repo un `.pfx`, `.pem`, ni una configuración de firma ya lista.

### Si quieres firmar la release

Necesitas instalar o tener disponible:

- **Windows SDK Signing Tools**
  - Incluye `signtool.exe`.

- **Certificado de firma de código**
  - Normalmente un `.pfx` con password.

Luego podrías firmar el `.exe` del instalador y, si quieres, también el ejecutable dentro de `build\windows\x64\runner\Release\`.

## Orden recomendado para publicar v0.4.0 de Windows

1. Instala Flutter SDK.
2. Instala el workload de C++ en Visual Studio.
3. Instala Inno Setup.
4. Instala AWS CLI v2.
5. Si vas a firmar, instala `signtool` y consigue el certificado.
6. Abre una terminal en `C:\Kumoriya`.
7. Ejecuta el script de publicación de Windows.

## Script preparado

El script preparado está en:

- `C:\Kumoriya\scripts\windows\build-and-publish-v0.4.0.ps1`

## Nota importante

El proyecto Windows del repo ya estaba casi listo, pero encontré y corregí un detalle importante:

- `kumoriya_installer.iss` apuntaba a `windows.ico`, pero ese archivo no existía.
- Ahora apunta al icono real: `runner\resources\app_icon.ico`.

Si quieres, después puedo dejarte un checklist todavía más corto, tipo “copiar y pegar en Windows”, o incluso un script de instalación de dependencias para PowerShell.
