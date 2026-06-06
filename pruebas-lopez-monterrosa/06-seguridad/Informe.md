Durante la ejecución de OWASP ZAP se realizó un escaneo automático sobre el servicio local identificado en el puerto 37989. La aplicación evaluada corresponde a una solución Flutter Desktop, la cual no expone una aplicación web convencional ni rutas HTTP navegables.

El servicio respondió con el código HTTP 403 (Forbidden) y el mensaje "missing or invalid authentication code", indicando que requiere un mecanismo interno de autenticación para permitir el acceso.

Debido a estas restricciones, OWASP ZAP no pudo descubrir recursos, páginas ni endpoints adicionales para analizar. Como resultado, no se detectaron vulnerabilidades clasificadas como High, Medium, Low o Informational.

Resultado del escaneo:

* Vulnerabilidades High: 0
* Vulnerabilidades Medium: 0
* Vulnerabilidades Low: 0
* Vulnerabilidades Informational: 0

Se concluye que el escaneo automático tuvo un alcance limitado debido a la naturaleza de aplicación de escritorio del sistema y a la ausencia de una interfaz web pública accesible para el análisis automatizado.


| Resultado               | Estado                   |
| ----------------------- | ------------------------ |
| Spider                  | Sin contenido detectable |
| Active Scan             | No aplicable             |
| Vulnerabilidades High   | 0                        |
| Vulnerabilidades Medium | 0                        |
| Vulnerabilidades Low    | 0                        |
| Informational           | 0                        |
