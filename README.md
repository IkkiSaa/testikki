# Delivery App — verificación NFC

Prototipo local para asociar un chip NFC con una entrega y verificar que el chip leído en la parada coincide con el registrado.

## Flujo

1. Entra en **Configurar NFC**.
2. Pulsa **Activar lector NFC** y acerca el teléfono al chip. En Android o iPhone físico, la app lee el identificador del chip; en una compilación debug sin NFC, aparece un campo para simular el identificador.
3. Completa cliente y dirección, y guarda la instalación.
4. Entra en **Repartidor**. Las entregas registradas en este dispositivo aparecen como paradas.
5. En una parada, pulsa **Leer chip y verificar entrega**. La entrega queda marcada solo si el ID coincide con el chip asociado.

## Ejecutar en Android Studio

- La carpeta ahora incluye `pubspec.yaml`; abre el proyecto Flutter y ejecuta `flutter pub get`.
- Puedes usar un emulador para recorrer las pantallas. Android Emulator no incluye hardware NFC, así que en debug puedes introducir IDs de prueba manualmente.
- Para leer tus chips reales, instala la app en un teléfono Android con NFC, activa NFC en Ajustes y escanea cada chip durante el registro. El emulador no puede leer los chips físicos.

## Probar en iPhone

El iPhone 14 Pro es compatible con NFC. La carpeta iOS incluye Core NFC, el texto de permiso y el entitlement de lectura. Para compilar e instalar la app iOS hace falta Xcode en una Mac y firmar la app con tu Apple Account. Sin Mac, no se puede ejecutar la compilación iOS desde Windows; se puede usar una Mac prestada/alquilada o un servicio macOS en la nube.

## Límites de este prototipo

- Las etiquetas y las entregas se guardan en `SharedPreferences` del dispositivo; no hay base de datos, sincronización ni cuentas.
- El acceso por rol es solo para navegar por el prototipo, no es autenticación.
- La verificación compara el identificador que expone el chip. Esto confirma que el ID coincide, pero no detecta una copia/clon del chip. Para confirmar autenticidad criptográfica o sincronizar repartidores se necesitaría otro diseño.
- La simulación manual solo está disponible en builds debug y no lee un chip.
