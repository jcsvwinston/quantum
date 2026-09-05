# CHANGELOG de la suite Quantum

Historial narrativo de los sets certificados. La entrada del set VIGENTE
vive en `versions.yaml` (`notes:`); al certificar un set nuevo, la entrada
anterior se mueve aquí (DX-25 — antes el manifiesto acumulaba ~4 300
palabras de historial interno en el fichero que la gente abre para saber
qué instalar).

## Quantum 1.26.2 — Corte fuera de cadencia: el consumidor de referencia vuelve a verde

Quantum 1.26.2 — corte fuera de cadencia, con la razón escrita que pide
QADR-0008: el consumidor de referencia quantum-app quedaba en rojo contra
1.26.1. Se mueven orbit (v1.8.20 → v1.8.25) y nucleus (v1.23.1 → v1.23.2, solo
documentación); quark v1.10.1 y todos los módulos hermanos de los tres
repos siguen donde estaban.

Lo que corrige orbit: la corrección OR-32 de la auditoría hizo que el
adaptador de Quark rechace los alias de base de datos que no sirve, en
vez de contestar en silencio desde la base equivocada. El listado de
modelos del panel pregunta por cada modelo en TODOS los alias de la app
para decir dónde vive cada uno, y convertía ese rechazo en un 500 para el
listado entero. quantum-app —que sirve «default» con modelos Quark y
«audit» con un módulo propio— lo cazó el mismo día. Ahora un alias no
servido cuenta como ausencia del modelo en ese alias, igual que una tabla
que no existe; un error en el alias propio del modelo sigue fallando.

Lo que este corte confiesa del anterior: el manifiesto de 1.26.1 perdió
la clave declared_lags y el final del comentario que la precede, por un
recorte calculado con un offset rancio al redactar las notas. Ningún
guard lo cazó: manifest-guard lee las claves con awk y una clave ausente
se lee como vacía, que es justo el valor que certifica. Desde este set
manifest-guard exige que las diez claves de primer nivel existan.

Del tren: release-please se auto-bloqueó al etiquetar por segunda vez en
el día («untagged, merged release PRs outstanding», ya con la acción v5),
las dos veces con un release PR único que llevaba paquetes sin cambios;
el tag salió por la receta manual del runbook. Y manifest-guard rechazó
la raíz de orbit v1.8.21 porque proto, agent y server llevaban bumps de
Dependabot (commits chore, que release-please no libera) sin tag que los
cubriera: liberarlos costó los tres cortes de la cascada de pines
internos (v1.8.22, v1.8.23, v1.8.24) más uno para quarkdatasource
(v1.8.25), y por el camino cayó un defecto
real: con solo handles de base de datos el panel elegía el alias por
defecto iterando un mapa de Go, distinto en cada arranque. Las dos cosas
tienen arco en el plan.

Con nucleus en v1.23.2 muere sola la transición auto-expirante del guard
de jerga servida que 1.26.1 llevaba ligada al pin v1.23.1: la fuente del
ejemplo ya no cita un ADR y el sitio lo sirve limpio sin excepción.

## Quantum 1.26.1 — La auditoría de madurez aplicada

Quantum 1.26.1 — el set que aplica la auditoría de madurez del
2026-09-03 (quark v1.10.1 con drivers en v0.1.1; nucleus v1.23.1 con los
doce módulos hermanos en v0.1.1 y providers/ldap v0.2.5; orbit v1.8.20
con proto v0.4.3, agent v0.6.12, server v0.10.14, quarkbridge v1.8.18 y
quarkdatasource v1.8.18). Patch en los tres pilares; la suite sube patch.

La auditoría midió cada pilar contra los frameworks con los que un equipo
compararía —GORM y ent; Gin, Buffalo, Encore, Django y Rails; Django
Admin, Filament y Directus— y encontró 147 defectos con fichero y línea.
Cuatro eran P0 y ninguno estaba en el runtime profundo: los cuatro
esperaban al evaluador en su primera hora. Quark rechazaba desde v1.10.0
los drivers registrados bajo alias (lib/pq, mattn/go-sqlite3): la
comprobación solo buscaba el alias, así que pedía importar un módulo que
ya estaba enlazado. Orbit nunca aplicaba el tls.Config a los listeners
del fleet: los flags de certificado se aceptaban y se ignoraban, y
configurarlos contaba como autenticación, así que un listener «con TLS»
arrancaba en claro, sin token y en todas las interfaces; el mTLS que la
doc anunciaba en ocho sitios no existía. El ejemplo canónico de Nucleus
no importaba el módulo del driver y salía con exit 1. Y la documentación
de entrada de Nucleus seguía diciendo «SQLite incluido» y «-tags mssql».

Lo que cambia para quien instala: los módulos de driver publicados
compilan solos (los de Quark requerían un core sin quarkdriver; los de
Nucleus, uno sin pkg/db/driver), `nucleus add otlp|prometheus` existe y
es lo que el arranque recomienda, el 500 genérico ya no filtra
err.Error() salvo en desarrollo, Data Studio valida con las etiquetas del
modelo y responde 422 por campo, el snapshot del sistema enmascara
cualquier variable con URL, DSN o credencial, y la SPA del panel hace lo
que dice: importa de verdad, «Load more» acumula, el JSON se edita como
JSON y una política deny se ve como deny. Orbit gana --agent-client-ca y
el agente habla https.

El paraguas cuenta por fin UNA sola historia sobre D3: README, RUMBO, la
página de instalación y el bloque require, go.work e integration.yml
descubren los 26 módulos publicables del árbol; el tren clasifica
cualquier release de módulo sin lista escrita; cuatro guards nuevos (32 en
total) cazan claims retirados en la fuente de nucleus y en el HTML
servido, un go.work que no cubra el manifiesto y un RUMBO que no diga el
set vigente. El anuncio a
quantum-app deja de ser fire-and-forget: espera el run y exige el PR, y
documenta el permiso del repo que falta para que exista.

Trampas del tren de este set, ya en el runbook: el push de la fusión de
un release PR NO disparó «Release Please» en nucleus (hubo que lanzarlo a
mano; el driver ahora lo detecta y lo dispara); quark tenía release-as
pegajoso y PRs por módulo, como nucleus antes de D3, y pasa a un solo
release PR; el driver no reconocía «chore: release main» y daba el merge
por bueno sin esperar tag, ahora lee los tags del manifest; y el guard de
voz de producto rechaza citar un ADR en las release notes. Y la trampa
estructural de orbit volvió a cobrar: agent y server se cortan del mismo
commit que proto y agent, así que nacen pinando el tag ANTERIOR; el
guard de pines internos lo rechaza al pin y hacen falta dos cortes de
convergencia (v1.8.19 agent→proto, v1.8.20 server→agent). Tres raíces de
orbit por un set, como en 1.26.0: el arco A3 del plan lo elimina de raíz.
Y una excepción declarada, auto-expirante: un comentario del ejemplo de
referencia de nucleus cita un ADR y el sitio lo incrusta en el quickstart
de todas las versiones, así que el guard de jerga servida se negó a
certificar v1.23.1. La fuente está corregida y publicada como nucleus
v1.23.2 (solo documentación; release-please se auto-bloqueó al cortarlo y
el tag salió por la receta manual del runbook), pero re-pinar a v1.23.2
habría obligado a tres cortes más de orbit, cuyos módulos requieren
v1.23.1. El set certifica v1.23.1 con la excepción ligada a ese pin —la
misma forma que la de ADR-010 en 1.25.0— y v1.23.2 entra en el siguiente
set semanal, momento en que la excepción muere sola.
Los informes completos y el plan a 5/5 están enlazados en docs/RUMBO.md.

## Quantum 1.26.0 — El arco D3 publicado: drivers, exportadores y backends de nube como módulos opcionales

Quantum 1.26.0 — el set que publica el arco de adelgazado del grafo (quark
v1.10.0 con sus cinco drivers en v0.1.0; nucleus v1.23.0 con once módulos
hermanos en v0.1.0; orbit v1.8.17 con agent v0.6.10, server v0.10.11,
quarkbridge v1.8.17, quarkdatasource v1.8.17 y proto v0.4.2 sin cambios).

Los dos puentes saltan de la línea 0.x a 1.8.17. Un Release-As del tren se
aplicó a todos los paquetes del repo de orbit y, cuando se detectó, el proxy
de Go ya los servía —y es inmutable—, así que volver a 0.x habría dejado un
`go get` público devolviendo una versión que este set no certifica. Se adopta
el número; ni el código ni la API de los dos módulos cambian.

Lo que cambia para quien instala: los drivers de base de datos, los
backends de nube y los exportadores de telemetría dejan de venir dentro
del framework y viajan en módulos propios, así que una aplicación enlaza
sólo lo que usa. Medido sobre un programa que enlaza pkg/app y nada más,
el hola-mundo de nucleus baja de 75,6 MB a 19 y de 346 módulos a 87; la
biblioteca de quark, de 24 MB a 6 y de 171 módulos a 129. Los dos
objetivos del arco —menos de 30 MB y menos de 150 módulos— quedan
cumplidos con margen.

La configuración no cambia ni una línea. database_url, otlp_endpoint,
metrics_path y storage.provider significan lo mismo; lo único nuevo es un
import en blanco, y `nucleus add <nombre>` hace el go get y lo escribe. Si
falta, el arranque para y el error trae las dos líneas exactas —también en
quark desde v1.10.0—. Desaparecen además los build tags mssql y oracle,
que nada en el código mencionaba y por eso fallaban en ejecución en vez de
al compilar.

Un módulo de driver registra DOS cosas —el driver y cómo ese driver
reporta una violación de unicidad—, y esa es la parte que no se puede
omitir: sin el clasificador la comprobación no falla, contesta que no. El
gate de seis motores de quark lo reprodujo en vivo antes de publicarlo, y
un test de orbit contra motor real lo volvió a cazar en un consumidor.

El único cambio de comportamiento del set es Prometheus: lo activaba
metrics_path, que tiene valor por defecto, así que quien scrapea el
/metrics por defecto lo pierde hasta añadir exporters/prometheus. La
aplicación avisa al arrancar y sigue; si la clave estaba escrita a mano,
para. Está en las notas de nucleus y en la doc pública.

El manifiesto estrena quark_modules y declara los diecisiete módulos
hermanos de los tres repos, que manifest-guard DESCUBRE del árbol en vez
de leerlos de una lista escrita a mano — la lista fija era el mismo fallo
que dejó once módulos publicables sin entrada en release-please. Y el
desfase del `require` de un módulo hacia su propia raíz pasa a AVISO: es
un suelo, no un pin, y Go resuelve al máximo, así que un consumidor
compila contra la raíz certificada de todos modos; el aviso dice los días
que lleva sin revisarse y la versión que lo deja al día.

## Quantum 1.25.0 — La auditoría integral de producto y DX, publicada

Quantum 1.25.0 (quark v1.8.0; nucleus v1.22.0 con providers/ldap v0.2.4;
orbit v1.8.14 con agent v0.6.9, server v0.10.9, quarkbridge v0.4.9,
quarkdatasource v0.2.18) es el set que lleva al público una auditoría de la
suite entera hecha con las manos: doce auditores ejecutando los CLIs,
siguiendo los quickstarts publicados con `go get` de tags reales, levantando
el panel y construyendo el sitio, más una verificación adversarial de cada
hallazgo grave. De 147 hallazgos, tres eran defectos que un evaluador pisaba
en su primera hora, y los tres están cerrados aquí.

**Los tres P0.** El quickstart de nucleus se publicaba con sus tres bloques
de código VACÍOS —las fences que importan el ejemplo no se resolvían en el
ensamblaje del paraguas—, y así llevaba en las trece versiones del sitio: el
paso «escribe tu primer módulo» no se veía. `nucleus generate module` con
cualquier nombre ya plural (`products`, `users`, `notes`) generaba una
aplicación que paniqueaba al arrancar por registrar dos veces la misma ruta.
Y el Data Studio sobre quark mostraba «—» en todas las celdas del propio
ejemplo certificado, porque el esquema declaraba columnas snake_case
mientras los registros llegaban con las claves del struct de Go.

**El sitio tiene por fin una puerta de entrada.** Hasta ahora eran tres
quickstarts sin relación entre sí: la portada bifurcaba a tres productos y
nada contaba la suite. Se estrena una sección /start con qué es Quantum y
para quién, un quickstart de los tres productos juntos derivado del ejemplo
que ya existía, una página que explica cómo elegir capa de datos y otra con
el bloque `require` del set generado desde este manifiesto. Y las primeras
capturas del panel: orbit es un producto visual que se documentaba solo en
prosa.

**En el código.** quark expone `NewWithDB` para montarse sobre el pool que
la aplicación ya tiene —la costura con nucleus—, valida columnas contra el
modelo con `WithStrictColumns` (un typo pasaba el guard y en SQLite devolvía
todas las filas sin error), deja filtrar por columnas cualificadas bajo un
JOIN y permite escribir una sola fila sin re-grabar las asociaciones
precargadas. nucleus elige líder para el scheduler de jobs —con el provider
asynq cada réplica arrancaba el suyo y los ticks se duplicaban—, completa
i18n y caché, que eran comandos sin runtime que los consumiera, y documenta
un login de punta a punta que antes había que reconstruir de cuatro sitios.
orbit dice su propio nombre en su interfaz, sirve un identificador opaco en
vez del token de sesión completo, cierra una carrera de datos alcanzable en
cada petición de esquema y pinta el SQL que su feed en vivo prometía.

**Y el tren.** La certificación pasa a ser semanal y desacoplada de los
arcos (QADR-0008): se pagaba el coste completo del tren casi por arco, 24
sets en siete semanas. La conducción vive ahora en `scripts/train/`, la
alineación de los seis módulos de orbit cabe en un commit, y el consumidor
de referencia externo vuelve a seguir el set en cada corte.

## Quantum 1.24.0 — Deuda del arco de anomalías QCD, saldada y medida

Quantum 1.24.0 — la deuda que dejó el arco de anomalías QCD, saldada y
medida (quark v1.7.1; nucleus v1.21.0 con providers/ldap v0.2.3; orbit
v1.8.13 con agent v0.6.8, server v0.10.8, quarkbridge v0.4.8,
quarkdatasource v0.2.17). Nada de esto son los catorce hallazgos de aquel
arco —ya cerrados en 1.23.0—; es lo que se observó mientras se arreglaban.
La regla del arco se mantuvo: medir antes de creer, y dos de las premisas
del encargo resultaron falsas al ejecutarlas.

§1 RELEASE-PLEASE YA ETIQUETA LAS MINOR DE NUCLEUS SIN INTERVENCIÓN, Y LAS
RELEASES TRAEN BINARIOS. Las minor v1.18.0, v1.19.0 y v1.20.0 se habían
fusionado con CI en verde y sin cortar el tag, y el diagnóstico de la ronda
—que la culpa era del árbol de docs versionadas que sólo las minor
añaden— era una correlación, no la causa. Medido: falla todo release PR de
SOLO-ROOT, porque su rama compartida no lleva componente y la vía standalone
del etiquetador lo compara contra la ruta del módulo y se rinde; las patch
que funcionaron llevaban el módulo ldap de acompañante. La cura es cortar
los release PR por componente. El mismo arreglo destapó que TODAS las
releases auto-etiquetadas de la historia salían con cero binarios —los tags
del token del bot no disparan el workflow de assets—, encadenado ahora
explícitamente. Ambas cosas verificadas EN VIVO al cortar este set: v1.21.0
etiquetó sola y salió con sus siete assets.

§2 EL RE-PIN DEL EJEMPLO YA NO ENROJECE TODOS LOS PRS A LA VEZ. El guard de
pins del showcase era de igualdad estricta, así que cualquier tag de un
hermano ponía en rojo cada PR abierto de nucleus —la ronda anterior necesitó
seis re-pins de emergencia—. Ahora tolera un minor de retraso con aviso, y
un escritor y un workflow cierran el retraso solos. El recordatorio sigue
existiendo (el aviso y el reloj de un minor); lo que desaparece es el bloqueo
de PRs ajenos.

§3 EL BORDE QUARKDATASOURCE→ROOT DE ORBIT VUELVE A ESTAR AL DÍA. Pinaba el
root diez parches por detrás dentro del mismo minor: tolerado hoy, pero un
minor del root lo habría sacado de rango en plena certificación. Subido antes
de que pudra.

§4 DOS DEFECTOS REALES DESTAPADOS BARRIENDO LOS TESTS QUE ENTRAN POR LA
PUERTA EQUIVOCADA. En quark, bajo RLS nativo la clave de la caché L2 no
llevaba el tenant, así que dos tenants con la misma consulta compartían clave
y el resultado cacheado de uno se servía al otro: el motor protegía la base
de datos, nada protegía la caché. En orbit, el navegador de ficheros del
panel no confinaba la ruta al directorio de subidas cuando había un backend
de almacenamiento configurado —la rama de producción—, así que una sesión con
permiso de lectura podía enumerar cualquier prefijo del bucket. Ambos con
rojo reproducido antes del arreglo; ambos con el test movido a la puerta real.

Y los cabos sueltos del arco: el modo de autorización abierta de nucleus
ahora sí decodifica el bearer (apagaba la autorización y de paso la
autenticación, dejando ciegos a interceptores y handlers); la vía documentada
para montar las rutas federadas tiene por fin un ejemplo ejecutable, que
destapó tres desajustes de la prosa; y los snapshots de documentación que
anunciaban una versión anterior —en nucleus y en orbit, visibles en el sitio
publicado— quedaron corregidos y con guardas que cazan también la forma que
se colaba sin marcador.

## Quantum 1.23.0 — Arco DX-3 y arco de anomalías QCD

Quantum 1.23.0 (quark v1.7.0; nucleus v1.20.1 con providers/ldap v0.2.2;
orbit v1.8.10 con agent v0.6.7, server v0.10.7 y quarkbridge v0.4.7). Dos
arcos que resultaron ser el mismo defecto visto desde dos alturas, más una
auditoría externa que midió la superficie de extensión ejecutándola.

§1 CLASIFICAR POR EL CÓDIGO DEL DRIVER, NO POR EL IDIOMA DEL MENSAJE. Quark
clasificaba errores de PostgreSQL contra el TIPO CONCRETO de pgx mientras su
guía prescribe lib/pq, así que bajo el driver documentado no reconocía nada
y tres decisiones fallaban calladas. El mismo defecto, un piso más arriba,
estaba en el bootstrap del panel de orbit: comparaba subcadenas INGLESAS del
mensaje. Reproducido con motores reales — un PostgreSQL con
lc_messages='es_ES.utf8' responde «llave duplicada viola restricción de
unicidad» y un MySQL con --lc-messages=fr_FR responde «Duplicata du champ» —
ninguna casaba, el duplicado no se reconocía y nucleus abortaba la
aplicación entera. Alcance real, sin exagerarlo: un reinicio normal no lo
toca, porque el recuento corta antes del insert; se alcanza en el primer
arranque concurrente de varias réplicas, donde las que pierden la carrera
entran en crash-loop. El predicado se exporta desde nucleus
(db.IsUniqueViolation) y no desde orbit porque pkg/db ya importa los cinco
drivers y el consumidor ya importa pkg/db: la delegación no añade ninguna
arista al grafo, mientras que implementarlo local obligaría a promover
cuatro drivers de indirect a direct.

§2 UN INTERRUPTOR DE APAGADO QUE BORRABA DATOS. `storage.cleanup.enabled:
false` no apagaba nada: el limpiador no guardaba el flag en ningún sitio y
las dos ramas del condicional devolvían structs idénticos, así que cada
arranque barría el prefijo — y barre una vez de inmediato, antes del primer
tick. Silencioso: nada registraba que hubiera arrancado contra un `false`
explícito.

§3 UNA CADENA DE AUTENTICACIÓN QUE DEJABA ENTRAR A QUIEN EL DIRECTORIO
ACABABA DE RECHAZAR. `auth_backends` trataba el rechazo y el no-alcanzable
con el mismo `continue`, así que una cuenta revocada en el directorio
entraba por una fila local rancia. Era una contradicción interna: el godoc
documentaba el fail-open mientras el README, la referencia de configuración,
el kit de conformidad para terceros y el README de orbit prometían lo
contrario. Gana la documentación. El arreglo es `break` y no `return`: con
[directorio caído, local rechaza] no se puede afirmar que la credencial sea
falsa, y un control que ya existía lo cazó. Consecuencia que conviene decir
en voz alta: una cadena es un FALLBACK ante indisponibilidad, no una forma
de federar varias poblaciones de usuarios.

§4 LA SUPERFICIE DE EXTENSIÓN DE v1.13–v1.17 NO ERA ALCANZABLE POR LA VÍA
QUE DOCUMENTA. Cinco costuras estrenadas y ninguna usable como se describe:
el adaptador que instala todo store de sesión configurado borraba sus
capacidades opcionales, dejando ciego al visor de sesiones del panel bajo
`session_store: redis`; la capa de validación comparaba `session_store`
contra un enum escrito a mano, así que un store de terceros lo construía el
contenedor y lo rechazaba el runner; la vía fluida no capturaba ni los
subárboles de interceptores ni los de instancias federadas, que arrancaban
con sus valores por defecto; `orbit.Config` sólo llevaba tags `yaml:`
mientras nucleus bindea con `koanf`, y 16 de sus 19 claves se descartaban en
silencio; y las rutas federadas que el arranque imprimía para registrar en
el proveedor de identidad no las montaba nadie, ni un test.

§5 LA LECCIÓN, PORQUE SE REPITIÓ TRES VECES. En el limpiador, en la cadena
de autenticación y en el store de sesión, el test que existía pasaba porque
entraba por una puerta que no es la que usa el framework — y así CODIFICABA
el defecto como comportamiento esperado. Al arreglar se movió el test a la
vía real, no se añadió un caso al lado. Y de los catorce hallazgos del
informe externo, dos resultaron ya arreglados o exagerados al medirlos: el
check de proxies de confianza ya juzgaba la unión de las entradas, y los
interceptores nunca pudieron reescribir la dirección de origen por delante
del limitador de peticiones. Medir antes de creer, incluido el informe.

## Quantum 1.22.0 — Arcos E y F del plan de extensibilidad

Quantum 1.22.0 — Arcos E y F del plan de extensibilidad (nucleus v1.17.0
con providers/ldap v0.2.0; orbit v1.8.6 de alineación; quark v1.6.1 sin
cambios). Los dos arcos que quedaban del plan, y los dos empezaron por
descubrir que el trabajo no era el que estaba anotado.
§1 (Arco E) LA AUTENTICACIÓN FEDERADA TIENE SU PROPIA COSTURA. El arco
estaba escrito como «SAML y OIDC», dando por hecho que la costura del
Arco A servía — y el propio repo lo afirmaba, en el test del registro:
«desbloquea LDAP, SAML y OIDC como módulos externos». Es cierto para uno
de los tres. backend.Backend es Authenticate(usuario, contraseña) y un
flujo federado no tiene credenciales que entregar: la persona se va al
proveedor de identidad y la respuesta llega a OTRA URL más tarde. La
afirmación se corrige en el mismo cambio que la deja de ser válida, que
es la única forma de que una frase falsa no sobreviva a quien la
descubre. pkg/auth/federated es un contrato SEGUNDO —Begin dice a dónde
mandar el navegador, Complete valida lo que vuelve—, paquete hoja con el
mismo techo de dependencias que los otros tres.
Lo que lo vuelve una costura y no una interfaz: EL STATE ANTI-CSRF ES DEL
FRAMEWORK y el proveedor no lo ve nunca. El framework lo emite, custodia
el flujo pendiente y rechaza un callback que no lo traiga ANTES de llamar
al proveedor. Un flujo de redirección sin esa comprobación funciona
perfectamente hasta que alguien lo ataca, así que al autor no se le da la
opción de olvidarla — la misma disciplina con la que el Arco A dejó los
tres resultados en el framework en vez de en cada backend. Cuatro
propiedades verificadas POR MUTACIÓN: state desconocido rechazado sin
consultar al proveedor, un solo uso, atado a la instancia que lo emitió,
y caducidad que además lo consume.
Parametrizable desde el .yml separando INSTANCIA y TIPO: `name` es la
instancia —el segmento de URL y el subárbol auth.<name>.*, el mismo canal
que un backend de credenciales— y `provider` es el protocolo registrado.
Dos proveedores de identidad del mismo protocolo es el caso ORDINARIO, un
tenant corporativo y uno de partners, y un registro con clave por tipo lo
habría hecho inexpresable sin publicar un segundo módulo.
La exención de auth.<instancia>.* es la primera que depende de la
CONFIGURACIÓN y no de un registro: la instancia es legítima porque el
operador la declaró. Habría sido la CUARTA aparición de «el mismo
fichero, dos veredictos» —los dos validadores corren en momentos
distintos y sólo uno tiene la declaración a mano—, así que la regla se
les pasa construida del mismo fichero, con test de que ambos aceptan lo
mismo y de que la exención es por instancia declarada y nunca de
namespace.
§2 (Arco F) UN TERCERO PUEDE INTERCEPTAR EL CICLO DE LA PETICIÓN. Este
arco no estaba definido en ninguna parte: era una etiqueta que se
arrastraba desde hacía tres sesiones sin ADR ni frase que dijera qué
problema cerraba. Se definió con el único respaldo escrito que había —
ADR-023 cierra diciendo que interceptar el ciclo de la petición es la
pieza siguiente— porque una etiqueta de plan sin contenido no es trabajo
pendiente, es una decisión sin tomar.
Interceptar HTTP SÍ se podía, pero no como plugin: AppBuilder.Use y el
campo Middleware de un módulo exigen que quien ENSAMBLA la aplicación
escriba el código, en el sitio y el orden correctos. Era el único hueco
con forma de registro sin registro, y por eso un interceptor no se podía
distribuir, sólo pegar en el arranque de alguien. http_interceptors es
una lista ORDENADA porque el orden ES el comportamiento, con
interceptors.<name>.* como subárbol, y se montan DENTRO del middleware
del framework: uno que desplazara el request ID, la sesión o el hook de
observabilidad rompería todo lo de abajo, incluido su propio log.
Al comprobar la premisa apareció lo que no estaba en la nota:
model.SetDefaultSQLObserver guardaba en un HUECO ÚNICO. pkg/app instala
el suyo al arrancar —es el que alimenta el bus de observabilidad y con él
la vista de SQL en vivo de Orbit—, así que un tercero haciendo lo ÚNICO
que ADR-023 dice que puede hacer apagaba ese bus al hacerlo. Sin error,
sin log y sin test que fallara: un feed que dejaba de actualizarse en el
despliegue de otro, atribuible a nada. Ahora suscribe, y un suscriptor
que entra en pánico queda contenido sin parar a los demás.
§3 EL PROVEEDOR LDAP COMO CONSUMIDOR DE PRIMERA PARTE. El Arco H prometía
que un proveedor dejaría de arrastrar el árbol del framework y la única
prueba era el test del propio paquete hoja. Migrado: 235 → 11 paquetes de
terceros en el paquete de producción. El go.mod NO baja de 143
indirectas, y está escrito así en vez de dejar que el número sugiera otra
cosa — el test en vivo carga un fichero real por pkg/app para probar el
cable de punta a punta, y la mejora es del grafo de COMPILACIÓN, no del
de módulos. Adoptar el kit de conformidad reprodujo aquí el fallo que el
kit existe para evitar: el primer directorio falso rechazaba el bind de
contraseña vacía, así que la suite pasaba con la guarda del backend
BORRADA. Un directorio real responde SUCCESS, y un fixture más amable que
la realidad no califica nada.
§4 LA DOCUMENTACIÓN PUBLICADA, MIRADA EN LO QUE SIRVE Y NO EN EL REPO.
Dos defectos que sólo se ven desde fuera. Cada snapshot versionado
anunciaba una versión que no era la suya —la doc archivada de 1.14.0
decía «the current release is v1.13.0»— y en la página que el sitio
publica en la RAÍZ, porque la última versión archivada es la que se sirve
por defecto; cinco salieron así, y la causa es de procedimiento: el
snapshot congela la doc antes de que release-please suba el marcador. Y
el comentario MDX del marcador se colaba como meta description, invisible
en la página —por eso nadie lo vio— y visible en un resultado de búsqueda
o al compartir el enlace. Los dos con guard nuevo y verificados por
mutación. También se completó el índice de ADRs, que se había quedado en
el 022 con veintinueve en el directorio: diecisiete decisiones sólo
alcanzables listando la carpeta, que es justo el estado que un índice
existe para evitar. El historial narrativo completo vive en CHANGELOG.md.

## Quantum 1.21.0 — Arcos H y G del plan de extensibilidad

Quantum 1.21.0 — Arcos H y G del plan de extensibilidad (nucleus v1.16.1
con providers/ldap v0.1.2; orbit v1.8.5 de alineación; quark v1.6.1 sin
cambios). Los dos arcos atacan la misma pregunta por lados opuestos: qué
le cuesta a alguien de fuera escribir un proveedor, y cómo sabe que lo ha
escrito bien. El Arco D dejó la costura utilizable; estos dos la dejan
barata y comprobable, que es lo que decide si nace un ecosistema o no.
§1 (Arco H) EL CONTRATO VIVE EN UN PAQUETE HOJA. La medición que lo
motiva, hecha antes de mover nada: implementar un backend de
autenticación obligaba a compilar 115 paquetes de terceros; uno de
almacenamiento, 301; uno de store de sesión, otros 115. Ninguno de esos
números tenía que ver con el contrato —tres métodos y dos errores
centinela— sino con que el contrato compartía paquete con el registro, la
validación de configuración y las implementaciones propias del framework,
y en Go importar un paquete es importar su grafo entero. Ahora cada
contrato tiene su hoja: pkg/auth/backend enlaza 2 paquetes de terceros,
pkg/storage/provider 2 y pkg/auth/sessionstore 0. Los nombres viejos
siguen siendo los MISMOS símbolos —alias de tipo, no copias—, así que
ningún consumidor cambia una línea: orbit se alineó sin tocar más que el
pin, y eso es la prueba, no la promesa. Dos tests de contrato lo
sostienen: uno fija el techo en 2 y otro exige que los alias sigan
resolviendo al tipo de la hoja. Hacen falta los dos porque esta deriva no
rompe ninguna compilación —solo engorda en silencio la de todos los
demás—, y una cifra que nadie vigila vuelve a subir. ADR-025 y ADR-026.
§2 (Arco G) EL CONTRATO TRAE SU PROPIO KIT DE CONFORMIDAD. De las
propiedades del contrato de autenticación, las que más cuesta acertar
estaban solo en prosa: que un rechazo y una fuente inalcanzable son
respuestas DISTINTAS —confundirlas hacia «rechazo» tira el servicio
entero, porque deja fuera también a la cuenta local de emergencia—, que
un usuario desconocido y una contraseña mala deben ser
indistinguibles, y que una contraseña vacía no es una credencial. Quien
lee la firma Authenticate(ctx, user, pass) no tiene modo de descubrir
ninguna de las tres. pkg/auth/backend/backendtest las convierte en siete
comprobaciones que un autor apunta contra su backend en cuatro líneas.
Los checks son funciones puras que devuelven error, adaptadas a testing.T
por Run, y eso es lo que permite lo importante: probar la suite contra
backends rotos A PROPÓSITO, exigiendo que se queje EL check correcto con
un mensaje que nombre el problema. Una suite que nadie ha visto fallar es
una suite que nadie sabe si muerde. Escribirla destapó un defecto en el
backend del propio framework: el adaptador del UserProvider no rechazaba
la contraseña vacía, delegaba la decisión —así que contra un proveedor
que devuelve el usuario sin comparar autenticaba—, y pasaba ese check
solo porque el proveedor de su test resultaba ser cuidadoso. Fuera a
propósito y escrito: los TIEMPOS. La propiedad es real y el backend LDAP
hace un bind señuelo por ella, pero una aserción de tiempo fiable
necesita más muestras de las que cabe pagar en una corrida, y un check
inestable sobre seguridad es peor que ninguno: se salta, y entonces nadie
mira. ADR-027.
§3 MAQUINARIA (nucleus v1.16.1). Un cambio en un proveedor corta ya CON
la raíz: el root excluía providers/ del cómputo de release, así que el
módulo hermano podía sacar tag sin que la raíz sacara el suyo — y el
manifest-guard §3b exige justo lo contrario, que el tag del módulo sea
ancestro del pin raíz. Era la causa estructural de que en el set anterior
hubiera que forzar la release a mano; v1.16.1 y providers/ldap v0.1.2 son
los primeros que salen del MISMO commit sin intervención.
§4 EL PARAGUAS. bump-set.sh, el escritor mecánico del set, no conocía el
bloque nucleus_modules —se añadió cuando nucleus pasó a multi-módulo y
nadie volvió al escritor—, de modo que la versión de ldap se transcribía
a mano en cada re-pin con el guard como única red. Ya lo escribe, leído
del manifiesto de release AL PIN y no del último tag publicado, que es la
diferencia que §3b vigila. Y se recuperó la entrada de Quantum 1.19.0,
que al certificar 1.20.0 se sobreescribió en versions.yaml sin llegar al
CHANGELOG: la regla DX-25 dice mover, y mover tiene dos mitades. El
historial narrativo completo vive en CHANGELOG.md.

## Quantum 1.20.0 — Arco D del plan de extensibilidad (LDAP integrado)

Quantum 1.20.0 — Arco D del plan de extensibilidad (nucleus v1.15.1 con su
primer módulo hermano, providers/ldap v0.1.1; orbit v1.8.3 de alineación;
quark v1.6.1 sin cambios). La pregunta de partida era si el primer
proveedor real debía ser un plugin o venir integrado, y se respondió
MIDIENDO en vez de suponiendo: LDAP añade tres módulos MIT y linka cinco
paquetes de terceros, mientras que SAML+OIDC juntos son treinta y dos
módulos y dieciocho paquetes. Contra un go.mod que ya carga los SDK de
AWS, Azure y Google Cloud, el argumento de las dependencias pesadas no se
sostiene para LDAP — pero sí para el arco siguiente, y por eso la costura
se queda igualmente. La forma elegida es módulo hermano en el repo del
framework: separado para el compilador y para go.mod, un solo producto
para el tren de release, la CI, la documentación y este manifiesto, que
pasa a certificar diez versiones de módulo en vez de nueve.
El arco no pudo empezar por el backend porque le faltaba el suelo: de las
cuatro factorías de registro del framework, la de autenticación era la
ÚNICA que no recibía configuración, así que un backend de directorio no
tenía de dónde leer su URL — y su propio godoc ya prometía el subárbol que
no existía. Al cerrarlo aparecieron dos defectos del arco anterior que
nadie había visto. El primero: la exención de clave desconocida vivía en
dos validadores y solo uno la tenía, de modo que un despliegue sobre un
backend de terceros arrancaba un servidor sano cuyo propio `check` llamaba
malformada a la configuración que estaba corriendo — «el mismo fichero,
dos veredictos», tercera aparición, ahora con una sola implementación y un
test que pregunta a los dos. El segundo no lo podía ver ninguna guarda:
configurar un backend y olvidar añadirlo a la cadena era un no-op
silencioso, porque el nombre SÍ está registrado y la sección está
legítimamente eximida, pero la cadena —su único consumidor— nunca la pide.
Del backend importa tanto lo que se niega a hacer: rechaza una contraseña
vacía antes de abrir conexión, escapa el nombre antes del filtro, trata un
match ambiguo como rechazo, y reserva el rechazo a UN solo código de
resultado — equivocarse hacia «no disponible» cuesta una caída al
siguiente backend, hacia «rechazo» cuesta la caída del servicio, porque
deja fuera también a la cuenta local de emergencia. Cada una de esas
propiedades tiene un test que falla si se quita la guarda, verificado por
mutación y no por lectura, y un lane en la puerta requerida contra un
OpenLDAP real que enlaza el módulo al árbol bajo revisión.
Lo que lo vuelve integrado y no un plugin: el arranque ya no responde
«backend desconocido» a un nombre que este proyecto publica, sino el
`go get` y el `import` exactos; hay `doctor --check auth`, que a propósito
no juzga registro porque corre en un binario que no importa los
proveedores de la aplicación; y la página del sitio dejó de decir que
Nucleus no trae cliente LDAP, que era cierto ayer.
Un apunte del tren, porque volverá a pasar: providers/ldap requiere la
RAÍZ DE SU PROPIO REPO, y ese borde no puede estar nunca perfectamente al
día — cualquier release que contenga su require es posterior a él. Es la
misma necesidad topológica que orbit documenta en root↔quarkdatasource, y
NO es la staleness cross-repo que declared_lags vigila: modelarlo como tal
dejaría el set incertificable para siempre. manifest-guard lo tolera un
release y lo dice con un AVISO, no con un «ok» indistinguible de un pin al
día — que es exactamente como el borde equivalente de orbit se pudrió un
ciclo entero sin que nadie lo viera. El historial narrativo completo vive
en CHANGELOG.md.

## Quantum 1.19.0 — Arcos B y C del plan de extensibilidad

Quantum 1.19.0 — Arcos B y C del plan de extensibilidad (nucleus v1.14.0,
orbit v1.8.1). §1 un proveedor REGISTRADO declara su propia configuración:
el Arco A dejaba enchufar un backend por nombre pero no configurarlo,
porque storage.ceph.endpoint moría como clave desconocida antes de que el
proveedor llegara a correr — un backend que nadie puede configurar es un
backend que nadie puede desplegar. La exención del guard es SOLO para
nombres registrados: un typo bajo storage. sigue fallando, o el namespace
se convertiría en un agujero donde cualquier errata pasa. §2 la superficie
que una extensión puede tocar deja de ser un cheque en blanco: el contrato
decía que podía «asignar campos en App», así que lo que tocara se volvía
API de hecho sin estar cubierto por nada prometible entre versiones — y no
lo usaba nadie (el único consumidor real lee cinco campos y no escribe
ninguno). Ahora lee, y lo que puede leer está congelado junto a los
símbolos, los comandos y las claves. §3 la cadena de autenticación se
declara con auth_backends y consume por fin auth.UserProvider, que llevaba
desde v0.x declarado, CONGELADO en el baseline y llamado por nadie. Un
backend no registrado rompe el ARRANQUE y no el primer login, que es el
peor momento para descubrir una errata en una lista de autenticación. §4
el panel de orbit autentica por esa cadena: quien configuró un directorio
corporativo obtiene login de directorio sin que orbit lleve un cliente
LDAP dentro. Delega la AUTENTICACIÓN, no la autorización — un usuario del
directorio que no esté dado de alta como admin se rechaza, porque sin esa
frontera conectar un directorio convertiría en silencio a toda la
plantilla en administradora del panel. Y al revés: una fila local no es un
bypass, la cadena sigue teniendo que aceptar la contraseña, así que una
cuenta revocada no entra por una fila rancia. La temporización se cuidó en
los dos sitios: el trabajo caro corre en TODOS los caminos antes de
decidir, o «no eres admin» respondería más rápido que «contraseña mala» y
volveríamos a publicar el enumerador de usuarios por otra puerta. quark
v1.6.1 sin cambios. §5 de propina, la certificación destapó que
orbit/quarkdatasource requería el root dos minors por detrás: dentro del
repo no se nota —el workspace resuelve el root desde el checkout— pero
quien instalaba ese módulo se llevaba de paso un root viejo. La excepción
que tolera un minor de lag en esa arista existe por una razón topológica
real, pero lo hacía imprimiendo una línea «ok» indistinguible de un pin al
día, así que el pin se pudrió un ciclo entero sin que nadie lo viera y el
guard sólo se puso rojo TARDE, en plena certificación, donde deshacerlo
cuesta un tag de root nuevo. Ahora avisa mientras el lag existe. El
historial narrativo completo vive en CHANGELOG.md.

## Quantum 1.18.0 — Arco A del plan de extensibilidad

Quantum 1.18.0 — Arco A del plan de extensibilidad (nucleus v1.13.0). El
problema que cierra: de seis subsistemas que eligen backend, exactamente
UNO era extensible desde fuera —el correo—; los demás lo elegían con un
switch sobre constantes, así que quien corre Ceph, Swift, un almacén
interno o un directorio corporativo no tenía más camino que forkear el
framework. Eso es lo que impide que nazca un ecosistema, y es la ventana
que conviene cerrar ANTES del lanzamiento, porque después cada contrato
cuesta una major con ventana de deprecación. §1 el almacenamiento se
registra por nombre (storage.RegisterProvider), y todo lo que el framework
pone encima —breaker, prefijo por tenant, mapeador de URL pública— se
aplica alrededor de lo que devuelva la factoría, así que un proveedor no
reimplementa nada. Había TRES puertas cerradas y no una: construcción,
validación de config y el paraguas de pkg/app. §2 el store de sesión
igual, con hook de apagado opcional para el que sostiene un pool. §3 la
costura de autenticación: auth.RegisterBackend más una CADENA ORDENADA,
que es lo que permite «el directorio primero, una cuenta local después» —
cuando el directorio no responde, alguien tiene que poder entrar a
arreglarlo. Tres resultados y no dos: aceptación, rechazo cierto y NO
DISPONIBLE; si todos rechazaron el llamante recibe credenciales
inválidas, y si alguno no respondía recibe un error que lo dice, porque
«contraseña mala» y «el directorio está caído» mandan al operador a
sitios muy distintos. Un error inesperado cuenta como no disponible: un
backend fallando de forma imprevista no puede dejar a todo el mundo
fuera. Dos cosas las cazaron los propios guards durante el arco: el
firewall de dependencias vio que el registro de sesión devolvía el tipo de
la librería interna, lo que habría obligado a cada autor de plugins a
depender de ella (ahora hay interfaz propia con tipos de stdlib y un
adaptador dentro), y el paraguas de storage caía a «local» por defecto,
así que un nombre mal escrito escribía las subidas al disco EN SILENCIO —
misma clase que los once hallazgos del set anterior. quark v1.6.1 y orbit
v1.7.4 sin cambios de comportamiento; orbit solo se alinea. El historial
narrativo completo vive en CHANGELOG.md.

## Quantum 1.17.1 — ronda de hallazgos de la demo externa

Quantum 1.17.1 — set de PARCHES que cierra la ronda de hallazgos de la
demo externa quantum-coverage-demo, re-verificada contra lo publicado: 11
defectos en los tres repos, dos de seguridad, todos de la misma clase —
reportan éxito y no hacen lo que dicen. quark v1.6.1: el preflight de RLS
comprobaba el NOMBRE de la política y nunca su predicado, así que una
política llamada <tabla>_tenant_isolation con USING (true) sacaba luz
verde mientras cada tenant leía las filas de todos; peor que no tener
check, porque un check en verde es lo que hace que dejes de mirar. Ahora
lee USING y WITH CHECK y exige referencia a la columna de tenant y lectura
de la variable de sesión. Además el preflight ya funciona con el cliente
que su propia documentación prescribe (usaba RawQuery, apagado por
defecto, y fallaba igual que una caída real) y los flags que no cambian el
veredicto se rechazan en vez de ignorarse. nucleus v1.12.1: siete
arreglos. Los dos primeros no son bugs sueltos sino del CONTRATO DE
EXTENSIÓN de ADR-022 — un módulo con Prefix no podía declarar su propia
raíz (el objeto más corto resolvía a «<prefix>/» y el enforcer casa con
keyMatch, donde esa barra es otra ruta), y CSRFExempt no tenía ni veto del
operador ni rastro en el arranque, de modo que un módulo SIN Prefix
declarando «/» apagaba CSRF en toda la aplicación, módulos hermanos
incluidos. S3Store.Delete no alcanzaba NUNCA el bucket público porque
RemoveObject es idempotente y el bucle cortaba en el primer nil: con
public_bucket configurado los objetos públicos eran indeleteables por la
API pública del Store, y Delete lo reportaba en verde. Una entrada mal
escrita de trusted_proxies se descartaba en silencio dejando la lista
vacía; y doctor security juzgaba esas entradas de una en una, así que un
catch-all partido en dos pasaba limpio cubriendo el mismo espacio que el
entero — con el agravante de que su mensaje nombraba la cabecera
equivocada (bajo catch-all lo explotable es X-Real-IP, no
X-Forwarded-For). nucleustest gana WithDatabases en el builder, porque la
remediación que el propio kit sugería no era expresable desde su entrada
principal, y avisa cuando la capa de entorno le cambia la base bajo el
test. Y nucleus version dice por fin su versión real tras un go install a
versión exacta, leyéndola de su propia build info como ya hacía quark.
orbit v1.7.3: el binding modules.orbit.* que el README documenta era
INERTE —los hooks tiraban la config bindeada y cerraban sobre la de
construcción, en silencio porque el módulo sí está montado—, así que quien
creyera haber fijado bootstrap_password no lo había fijado; más la
alineación al set. Método: rojo-sin-fix ANTES de cada arreglo, y los dos
de seguridad con test que FABRICA la condición insegura y exige que el
producto la detecte — un test del camino feliz no habría valido, porque el
hallazgo era justo que el check pasaba en verde sobre algo peligroso. El
historial narrativo completo vive en CHANGELOG.md.

## Quantum 1.17.0 — orbit versiona su documentación

Quantum 1.17.0 — orbit v1.7.0 versiona su documentación, y con eso los TRES
productos publican archivo por minor. Era el único que servía siempre su doc
actual: quien corría orbit 1.2 leía la del set vigente sin que nada se lo
dijera. El paraguas lo sabía —lo decía un comentario de su config— pero el
lector no. NINGUNA ruta se mueve: lastVersion current mantiene la doc actual
en /orbit/ y los snapshots aparecen aparte; el cambio es aditivo. El corte no
usa `docusaurus docs:version` porque orbit no tiene instalación propia (su
website/ es solo docs/ y el sitio lo ensambla el paraguas, QADR-0003): son
tres operaciones de fichero, y como su sidebar es AUTOGENERADA desde la
estructura de carpetas, la versionada es la misma declaración de una línea —
añadir una página no obliga a tocar nada. HUECO HISTÓRICO DECLARADO: el
archivo empieza en 1.6.7, la versión publicada al instalar el versionado; las
minors 1.0-1.5 no tienen snapshot y NO se fabrican, porque un snapshot
retroactivo afirmaría que la doc de hoy fue la de entonces — la mentira que
este mecanismo existe para impedir. Registro de guards 21 → 22 con
orbit-docs-archive y su fixture. Dos cosas las cazaron los guards durante el
arco, ambas del propio cableado: el guard nº17 de enlaces vio que el «Edit
this page» de los snapshots apuntaba a orbit_versioned_docs/, el prefijo de
ENSAMBLADO del paraguas, que en el repo de orbit no existe (mismo replace que
ya tenía quark); y el guard de frescura recién instalado mordió su primer
caso real al exigir el snapshot de 1.7.0. Además se REVIRTIÓ un arreglo
propio: hacer que la matriz de módulos leyera el manifiesto para cerrar su
ventana rancia dejaba el PR de release en ROJO sin arreglo posible —empujar a
una rama de release-please la deja sin CI—, así que se asume la ventana y
queda escrito en el script POR QUÉ el arreglo obvio no vale. quark v1.6.0 y
nucleus v1.12.0 sin cambios. El historial narrativo completo vive en
CHANGELOG.md.

## Quantum 1.16.0 — Track E de nucleus (seguridad y cumplimiento)

Quantum 1.16.0 — Track E de nucleus (v1.12.0), el track de seguridad y
cumplimiento del roadmap enterprise, cerrado con evidencia. §1 el perfil de
hardening por defecto queda CONGELADO y, sobre todo, MEDIDO: un test arranca
una app real, le manda una petición real y graba lo que vuelve —cada cabecera
de seguridad, los atributos de cada cookie, lo que recibe un llamante
cross-origin— para los perfiles de desarrollo y producción, y lo compara byte
a byte contra un baseline versionado. Nada se transcribe, así que el fichero
no puede afirmar una protección que el framework no emite, que es el modo de
fallo de todo checklist de seguridad escrito a mano. La comparación es EXACTA
en ambos sentidos: aflojar un default es la regresión que esto caza,
endurecerlo es un evento de compatibilidad para quien dependía de la postura
anterior, y los dos exigen regenerar el baseline a propósito — que es el
criterio de salida «security-sensitive config changes always
compatibility-reviewed» en forma mecánica. §2 nucleus doctor --check security
cubre la configuración que carga bien y expone mal: CORS con comodín (fatal
con credenciales, que el estándar Fetch prohíbe), trusted_proxies con
catch-all (X-Forwarded-For bajo control del atacante), jwt_secret largo pero
adivinable (health --deploy mide LONGITUD y 32 caracteres iguales la pasan),
csrf_insecure_cookie en producción y rate limiting apagado. §3 los prefijos
__Host-/__Secure- se juzgan al cargar y no al arrancar: vivían solo en el
constructor de sesiones, así que una cookie imposible cargaba limpia y mataba
la app al arrancar. Exclusión DECLARADA: no se activa el rate limiting por
defecto — voltear ese default haría que cada despliegue existente empezara a
rechazar tráfico al actualizar, y eso pertenece a un major con ventana de
deprecación. Además, cinco hallazgos de la pasada posterior al track: config
print era la última superficie del CLI que leía configuración sin juzgarla
(ahora avisa por stderr y sigue renderizando); el bodycheck marcaba como
deriva las claves de módulo y los nombres elegidos por el usuario, dejando
permanentemente en rojo la página que enseña a configurar módulos; la página
pública anunciaba la capa 3 de validación como «rolling out» meses después de
que corriera en cada carga; el orden código-antes-que-prosa quedó escrito en
el mensaje del propio guard y en CONTRIBUTING; y el snapshot de documentación
se corta ahora el ÚLTIMO de los cambios de la ronda, porque un corte anterior
congela el texto equivocado para siempre y ningún guard lo ve. orbit v1.6.7:
alineación al set de root, server, agent y quarkbridge (quarkdatasource y
proto no requieren nucleus). quark sin cambios en v1.6.0. Nombre 1.16.0
(minor): el minor de nucleus arrastra el número de suite (QADR-0002). El
historial narrativo completo vive en CHANGELOG.md.

## Quantum 1.15.0 — Arco DX-2 y consolidación documental

Quantum 1.15.0 — Arco DX-2 (ergonomía de test y de contribuidor) y
consolidación de la documentación. quark v1.6.0: §1 quarktest, kit de
pruebas del ORM — SQLite(tb) da una base por test respaldada en fichero (no
:memory:, que rompe con pools), Migrate(tb, client, models...) levanta el
esquema desde los modelos y Tx(tb, client, fn) ejecuta el caso dentro de una
transacción que SIEMPRE revierte; §2 quarktenant.VerifyRLSPolicies convierte
el aislamiento multi-tenant en un preflight verificable (lee
pg_class.relrowsecurity/relforcerowsecurity y pg_policies, devuelve hallazgos
por tabla y sale 1 con ErrRLSNotEnforced) — antes «RLS activo» era una
creencia, ahora es una comprobación; §3 make check reproduce en local la
puerta de CI completa. nucleus v1.11.0: §1 nucleustest crece de arrancar un
servidor a cerrar el círculo — Runtime(), DB(), TempSQLite(t) y MigrateDir()
permiten afirmar contra la base con el esquema real (el kit monta un módulo
sonda; el nombre nucleustest_probe queda reservado); §2 la validación de
configuración emite UN solo veredicto: ValidateSemantics y ValidateReferential
viven en pkg/app y LoadConfig las ejecuta siempre, así que un fichero
inválido falla al cargarse y no tres capas más abajo; §3 parada grácil del
outbox — Stop() deja terminar la pasada en vuelo (RunGraceful,
GracefulStopTimeout de 5 s) y solo entonces escala a cancelación dura. NOTA
honesta sobre §3: nace de un pánico de carrera visto UNA vez en la lane de
race de CI (database/sql (*Rows).close→awaitDone); no se logró reproducir con
estrés (-race -count=100, GOMAXPROCS variado), así que no se declara
arreglado: lo que se entrega es un contrato de parada mejor, con su test en
rojo antes del fix, no un diagnóstico cerrado. orbit v1.6.6: alineación de
deps al set (agent v0.5.14, server v0.9.10, quarkbridge v0.3.13,
quarkdatasource v0.2.12; proto sin cambios) en UNA ronda — el pin de agent se
subió dentro de la propia release de server, que es lo que colapsó la cascada
de dos rondas extra de los dos sets anteriores. Documentación: reescritura
editorial de las páginas públicas de los tres productos (58 en total) para
que se entiendan sin conocer el código; el archivo versionado queda
consolidado con herramienta y guard propios (cut_docs_snapshot.sh corta el
snapshot ANTES de que entre la release, check_docs_archive_freshness lo
exige, y el checklist de release lo pone como paso 0) — no se rellenaron
snapshots retroactivos: se documenta el hueco en vez de fabricarlo. Paraguas:
guard nº17 (los enlaces del sitio construido se verifican contra los
checkouts locales, sin red) y scripts/bump-set.sh, la capa 1 de automatización
de docs — el escritor mecánico del set. Nombre 1.15.0 (minor): los minors de
quark y nucleus arrastran el número de suite (QADR-0002). El historial
narrativo completo vive en CHANGELOG.md.

## Quantum 1.14.0 — Arco vertical slices (ADR-022)

Quantum 1.14.0 — Arco vertical slices (ADR-022 de nucleus, v1.10.0): un
módulo montado lleva ahora TODO lo que su feature necesita. §1 Policies y
CSRFExempt declarables (filas RBAC relativas al Prefix, solo in-memory; un
deny del CSV anfitrión anula cualquier allow de módulo); §2 las Migrations
embebidas se aplican con una llamada deliberada (Runtime.ApplyModuleMigrations,
ledger con namespace por módulo + checksums, idempotente; el boot sigue sin
mutar esquema por sí solo — ADR-013 §R1); §3 Templates fs.FS por módulo bajo
su namespace (app.WithTemplatesFS, acumulativo; templates_dir del anfitrión
gana la colisión); §4 nucleus generate module emite el slice
paquete-por-feature autocontenido — el E2E del guard de scaffold arranca sin
migrate y sin tocar rbac_policy.csv. quark v1.5.2: migrate up sin --steps
aplicaba SOLO la primera migración pendiente (default del flag compartido
entre up/down) y salía 0 — clase «exit 0 sin efecto». orbit v1.6.5:
alineación de deps al set completa en dos pasos cazados por los guards
(v1.6.3 dejó agent en nucleus v1.9.1 — manifest-guard §5; v1.6.4 dejó a
server pinando agent v0.5.12 — orbit-internal-pins): server v0.9.9,
agent v0.5.13, quarkbridge v0.3.12, quarkdatasource v0.2.11, proto sin
cambios. Además: los 206
enlaces «Edit this page» del sitio publicado estaban rotos (editUrl string)
y quedaron corregidos con editUrl-función por instancia. Nombre 1.14.0
(minor): el minor de nucleus arrastra el número de suite (QADR-0002). El
historial narrativo completo vive en CHANGELOG.md.

## Quantum 1.13.0 — Arcos QCD-FW-4..11

Quantum 1.13.0 — Arcos QCD-FW-4..11 (la re-verificación continua de la demo
externa sobre la serie v1.8.x/v1.9.x de nucleus; quark v1.5.0 y el resto del
set continúan del 1.12.0). nucleus v1.9.1 acumula: FW-4
create_bucket_if_missing alcanzable desde nucleus.yml + paridad de espejos
de config por reflexión; FW-5 knobs de outbox (missing_route_policy,
lease_owner por instancia); FW-6 Flush sin pánico; FW-7 plantillas
recursivas con nombre por ruta relativa y scaffold renderizable; FW-8
newChild como única derivación de sub-routers (los módulos con Prefix
reciben motor y sesión — y el session manager por fin cableado al árbol);
FW-9 WithTemplateFuncs/WithTemplates; FW-10 el dispatcher del outbox
arranca tras las extensiones; FW-11 el builder re-expone toda app.Option
con guard de paridad app↔builder, y el baseline de API congelado exige
regenerarse ante adiciones. Suites nuevas en CI: conformidad SSR de 5
puntos y scaffold ejecutable. orbit v1.6.2: alineación de deps a nucleus
v1.9.1 (agent v0.5.12, server v0.9.7, quarkbridge v0.3.11; proto y
quarkdatasource sin cambios). Nombre 1.13.0 (minor): el minor de nucleus
arrastra el número de suite (QADR-0002). El historial narrativo completo
vive en CHANGELOG.md.

## Quantum 1.12.0 — Arco DX

Quantum 1.12.0 — Arco DX (informe de auditoría DX 2026-08-16: los 27 ítems
del backlog DX-1..DX-27 cerrados en producto con rojo-sin-fix donde
aplicaba, más los casos "exit 0 sin efecto" A4/A5). quark v1.5.0 (minor):
DDL de dominio con migrate create --from-models, vocabulario rico del
generador de modelos, timestamps automáticos, runner embebido de init,
linter de tags fail-fast, error accionable sin PK, build sin CGO y
quark.New estricto (opciones inválidas y driver desconocido = error).
nucleus v1.8.0 (minor): generate resource/startapp emiten Module()
montable con repositorio SQL real por dialecto, kit de test in-process
pkg/nucleustest + RunContext, profile: dev sin Docker, config estricta con
did-you-mean y el acantilado del quickstart convertido en test. orbit
v1.6.1: quick-start compilable, Makefile a 6 módulos, matriz de
compatibilidad generada, módulos re-pinados al set. Paraguas: guard nº16
umbrella-exit0-regressions (los 7 repros §4.A al pin), lane showcase-smoke
en integration.yml, quantum-env.sh y manifiesto a 9 módulos con
print-requires.sh. Minors de quark y nucleus fuerzan el minor de suite
(QADR-0002). El historial narrativo completo vive en CHANGELOG.md.

## Quantum 1.11.0

Quantum 1.11.0 — Arco QCD-FW (micro-arco de features dirigido por los
hallazgos de framework de quantum-coverage-demo; Quantum 1.10.1 seguía
certificada). Cierra los dos hallazgos que el arco QCD-CLI dejó
registrados con workaround declarado, más el cableado prometido en
v1.6.2. **nucleus v1.7.0 (minor):** QCD-FW-1 — el authz global
default-deny ve claims JWT: App.New monta el decoder opcional de bearer
por delante del enforcement y el middleware resuelve sujetos en orden
uid → rol → anonymous (primer permitido gana; el fallback anonymous
preserva el allowlist de bootstrap para autenticados — dirección
estrictamente no-restrictiva). El RBAC por roles del CSV de AUTH_GUIDE
es alcanzable en la capa global sin replicarlo por módulo. QCD-FW-2 —
bootstrap de buckets S3: CreateBucketIfMissing (opt-in, provisiona al
construir) y S3Store.EnsureBucket (programático, idempotente); cambio
declarado: sin opt-in, un bucket ausente falla ALTO en el constructor en
vez de bootear verde y reventar en el primer Put. Además,
ServiceRegistration.Health cableado a /healthz como service:<name> (503
si falla), con health.FuncProbe y app.RegisterHealthProbe como piezas
reutilizables. **orbit v1.5.4 (patch):** alineación pura de deps a
nucleus v1.7.0 (agent v0.5.10, server v0.9.5, quarkbridge v0.3.9; proto
y quarkdatasource sin cambios). **quark v1.4.1:** sin cambios, continúa
del set 1.10.1. La demo puede retirar sus dos workarounds declarados
(fila-puerta anonymous + RBAC por módulo, y el MakeBucket a mano en
OnStart). Nombre 1.11.0 (minor): el minor de nucleus arrastra el número
de suite (QADR-0002).

## Histórico

--- Quantum 1.10.1 (histórico) — Arco QCD-CLI (micro-arco de reparación, NO una ronda;
Quantum 1.10.0 seguía certificada). Primera vez que el detector es EXTERNO:
quantum-coverage-demo, un consumidor independiente que ejercita la suite
solo por module proxy, reportó 5 hallazgos de CLI con repro rojo ejecutado
(QCD-CLI-1..5) más papercuts de doc (QCD-FW-3); todos cerrados en producto
con disciplina rojo-sin-fix. **quark v1.4.1 (patch):** QCD-CLI-1 model
generate --fields compila y declara PK (imports derivados de los campos,
tag quark solo con vocabulario del ORM), QCD-CLI-2 receta de embebido con
commands.Main() que propaga errores (la impresa por el propio CLI salía 0
en silencio), QCD-CLI-3 tenant provision completa bajo schema_per_tenant
con gate de idempotencia en quark_tenants antes de cualquier DDL, más
papercuts (migrate status con pendientes y sin error en base fresca,
seeders en orden de registro, init lee go.mod, InstallRLSPolicies
re-ejecutable con DROP POLICY IF EXISTS — cambio de comportamiento
declarado). **nucleus v1.6.2 (2 patches):** QCD-CLI-4 generate
resource/startapp emiten DDL del dialecto de la base configurada (exports
nuevos db.SystemFromURL y model.BuildMigrationScaffoldForSystem) con
--dialect/--config/--database; QCD-CLI-5 loaddata carga en orden
topológico por FKs introspectadas y respeta --tables (round-trip
dump→load en una invocación); papercuts QCD-FW-3 (healthz honesto, import
path de storage, acciones CRUD en AUTH_GUIDE, Health sin cablear
declarado). **orbit v1.5.3 (2 patches):** alineación pura de deps (quark
v1.4.1, nucleus v1.6.2) en v1.5.2, y v1.5.3 recoge proto/v0.4.2 — la
directiva go del bump transversal tocó proto/go.mod y el guard §3 exige
que el pin no lleve código de módulo sin publicar; su onda re-pina agent
(v0.5.9) y server (v0.9.4). **Transversal a los tres pilares:**
toolchain/directiva go a 1.26.6 (CVEs stdlib GO-2026-6218/6091/6090/6089),
grpc v1.82.1 (GO-2026-6061) y otel v1.44.0 (GO-2026-5158) donde eran
alcanzables. Quedan REGISTRADOS para un arco propio (feats → minor):
QCD-FW-1 (la capa global de authz nunca ve claims JWT) y QCD-FW-2 (S3Store
sin bootstrap de bucket) — la demo opera con workarounds declarados.
Nombre 1.10.1 (patch): solo patches en los tres pilares (QADR-0002).

--- Quantum 1.10.0 (histórico) — Arco de endurecimiento #1 (micro-arco de hardening, NO una
ronda; Quantum 1.9.0 seguía certificada). Cierra a CERO el backlog de
REVISION_DIRIGIDA_SEG_1 — la primera revisión dirigida de seguridad del
régimen de auditoría continua: SEC-1..4 y MAQ-1..5. Nombre 1.10.0 (minor) y
no «1.9.1» porque el minor de nucleus (v1.5.0→v1.6.0) obliga al número de
suite a reflejar el vX.Y.Z real (QADR-0002). La revisión halló el FRAMEWORK
(quark/nucleus/orbit) LIMPIO: la seguridad accionable estaba en la app de
referencia (que enseñaba un anti-patrón que otros copian) y en la maquinaria
de guards; SEC-3/SEC-4 entran en nucleus como defensa en profundidad.
**quantum-app v0.1.2 (SEC-1, SEC-2 — lo más importante del arco):** mata el
anti-patrón credential-by-default. main es fail-closed — mustEnv rechaza
WAREHOUSE_OUTBOX_SECRET y WAREHOUSE_OPS_PASSWORD si van sin valor, vacíos, o
con uno de los valores-ejemplo públicos del repo (dev-outbox-secret,
warehouse-ops): el boot MUERE alto y claro en vez de arrancar sobre una
credencial que vive en el árbol. Y se eliminó el downgrade a token estático
del hook del outbox: /hooks/outbox exige la firma HMAC del cuerpo y nada más
(rojo-sin-fix demostrado: con el downgrade reintroducido, «sin cabecera de
firma + buen token» iba a 200; con el fix, 401). Alineado además a SEC-3: el
consumidor decodifica por el encoding CONFIGURADO
(WAREHOUSE_OUTBOX_ENCODING), nunca por la cabecera sin firmar, y rechaza el
mismatch (400). E2E Docker 7/7 real. **nucleus v1.6.0 (minor; SEC-3, SEC-4,
MAQ-5):** SEC-3 — decisión Opción 2: la cabecera X-Outbox-Payload-Encoding se
queda INFORMATIVA/sin firmar (firmarla habría bifurcado el esquema de firma
body-only, un verificador para webhooks de módulo y de outbox, pineado por un
test); el helper nuevo de consumidor outbox.CheckPayloadEncoding + el
centinela ErrPayloadEncodingMismatch cierran el hueco en el lado que decodea;
el wire NO cambia. SEC-4 — el boot rechaza path=="/" y nombres de módulo con
«..» o «/» (defensa en profundidad). MAQ-5. Este minor de nucleus es el que
arrastra el número de suite. **orbit v1.5.1 (+ agent/v0.5.6, server/v0.9.1,
quarkbridge/v0.3.6; quarkdatasource/v0.2.7 y proto/v0.4.1 sin cambios):**
MAQ-3 — la excepción root-edge del guard de pins internos se ciñe al ÚNICO
borde topológicamente forzado (root↔quarkdatasource, por directorio
consumidor) y verifica el contrato de datasource congelado contra la línea
base de ADR-001; alineación de deps a nucleus v1.6.0, sin cambios de
comportamiento de orbit. **Maquinaria del paraguas (MAQ-1, MAQ-2, MAQ-4):**
las dos costuras del guard del tag de suite — MAQ-1/B.1 assert 5 (el tag
CAPTURA HEAD: gitlinks del tag == gitlinks de HEAD == workspace_pins de HEAD;
un tag rancio-pero-autoconsistente pasaba los asserts 2-4 y moría solo aquí),
MAQ-2/B.2 modo certificación (--cierre / QUANTUM_CERTIFYING=1) que trata el
AVISO mid-tren «versión sin tag» como NO-PASA y exige la captura de HEAD, de
modo que «15/15 EXIT=0 en --cierre» solo puede significar «tag cortado que
captura HEAD»; MAQ-4 endurece el notificador de fallo del schedule. Esta
certificación ESTRENA el modo --cierre. **Seguridad transversal:**
GO-2026-5970 (bucle infinito en x/text) se mantiene en v0.39.0 (arrastrado
por MVS). Reglas del arco cumplidas: cada guard nuevo/modificado probado en
negativo y con fixture en guard-of-guards; cada fix de seguridad con
rojo-sin-fix demostrado; E2E de quantum-app 7/7 con Docker real; tren en
orden de dependencia; tag de suite tras el último PR. El cierre SOLICITA una
verificación humana dirigida ACOTADA a (a) SEC-1/SEC-2 no dejan vivo ningún
camino de auth débil y (b) B.1/B.2 no rompen un flujo de certificación
legítimo.

--- Quantum 1.9.0 (histórico) — 8ª ronda (consolidación final; nombre 1.9.0 y no «1.8.1»
porque release-please dictó MINORS en los tres pilares — QADR-0002 obliga
al número de suite a reflejar el vX.Y.Z real): backlog de la 8ª auditoría a
CERO y ACTIVACIÓN del régimen de auditoría continua — a partir de la 9ª la
certificación descansa en la lane semanal + juicio humano puntual, sin
pasada manual completa (dictamen de la 8ª). Esta ronda ES la primera
certificación por el régimen nuevo: Quantum 1.9.0 se certifica con
suite-integral 15/15 EXIT=0 + guard-of-guards 15/15 + CI por-repo verde +
E2E de quantum-app, SIN pasada manual. **quark v1.4.0 (minor):** modo
estricto de lecturas opt-in (WithStrictReads — WARN/reject de Iter/Cursor
sin límite + detección N+1 por contexto con TrackReads y escape
AllowUnbounded, coste cero apagado), contador BlockedPanicCleanups (hace
observable un cleanup de pánico del RLS bloqueado), WithLimits normaliza
los campos numéricos a cero desde DefaultLimits con WARN si un literal
parcial deja SafeMigrations=false. **nucleus v1.5.0 (minor):** EL FRENO —
el contrato del webhook del bridge del outbox versionado y firmado en UN
cambio (firma HMAC-SHA256 en X-Nucleus-Signature con secret por bridge,
cabecera X-Outbox-Payload-Encoding json|base64, default base64 = wire de
v1.4.0 byte a byte con #230 como opt-in, y test de contrato del CUERPO byte
a byte — el hueco que el freeze de símbolos no ve); Oracle pagina con
OFFSET/FETCH en pkg/model (era SQL inválido en un paquete stable — NU8-1) +
§2.6 de la 7ª; webhooks con path canónico obligatorio (boot falla) y
anti-replay opt-in por timestamp firmado; regla de IDs de hallazgo en el
linter de voz; lane Oracle endurecida con el healthcheck del contenedor
(gateaba solo el puerto → flake ORA-12514). **orbit v1.5.0 (+ agent/v0.5.5,
server/v0.9.0, quarkbridge/v0.3.5, quarkdatasource/v0.2.7):** el feed vivo
HTTP in-process POR FIN funciona (v1.4.4 lo sobre-prometía — nota corregida
en las release notes, OR8-1); alineación de deps al set; la excepción
root-edge del guard de pins se amplió a ≤1 minor de lag (topológicamente
forzado cuando el root cruza un minor). **quantum-app v0.1.1:** requireUser
en lecturas de pedidos (PII), datasheets con nosniff+attachment, unit tests
reales, imágenes minio/mailpit pinadas, el consumidor del outbox verifica
la firma con hmac.Equal, y un gate nuevo (check_human_labels) que asierta
README+TUTORIAL contra go.mod (QA8-1). **Gobernanza (paraguas):**
integration.yml con schedule semanal + issue automático en fallo (QM8-1);
runbook AUDITORIA_CONTINUA.md §6 con los disparadores de mini-pasada, el
decisor y la plantilla de CIERRE (regla nueva: un ✅ con asimetría conocida
se escribe ⚠️); guard del tag de suite (QM8-6); robustez QM8-3..8 (el
15º guard, umbrella-suite-tag, entra al registry y al guard-of-guards).
**Seguridad transversal:** GO-2026-5970 (bucle infinito en x/text) elevado
a v0.39.0 en los cuatro repos. **Este arco toca superficie de seguridad
(firma del bridge, auth de orders, paths de webhooks, anti-replay) y la
propia maquinaria (root-edge, lane Oracle, schedule) → el cierre SOLICITA
una revisión humana dirigida SOLO a esa superficie, primera aplicación del
régimen nuevo (disparadores §6.1 y §6.3).** Tren en orden de dependencia,
tag de suite tras el último PR.

--- Quantum 1.8.0 (histórico) — cierre de la 7ª ronda («cierre definitivo»): backlog de la
auditoría a CERO (los 3 restos de la 7ª pasada + P3 completo), lags
cross-repo a CERO (declared_lags vacío por primera vez desde que existe la
sección), y la certificación convertida en MECÁNICA: lane suite-integral
(los 14 guards de los 4 repos ejecutados AL PIN + gate de declared_lags
vacío) y guard-of-guards (14 fixtures de fallo que prueban en CI que cada
guard sigue mordiendo, con aserción anti-fósil de guards sin registrar y
cobertura fixture↔guard en ambas direcciones) + runbook
AUDITORIA_CONTINUA.md. **nucleus v1.4.0 (minor):** Jobs y Webhooks de
módulo EJECUTÁNDOSE — JobRegistry/WebhookRegistry ganan Register real
(aditivo sobre la forma congelada, como preveía el waiver W3 de ADR-013):
jobs sobre los providers existentes de pkg/tasks (memory/asynq vía
jobs_provider) con Every/Cron validado, Timeout y Singleton; webhooks como
rutas reales bajo webhooks_prefix con verificación HMAC-SHA256 en tiempo
constante (401 antes del handler), allow-list de métodos, tope de body y
exención CSRF automática del prefijo; registro inválido = boot falla; los
WARN «not executed» eliminados porque ya no son verdad. El estreno destapó
y corrigió un bug real de pkg/tasks: el Manager.Run de asynq esperaba
señales del SO y era imparable por API (ctx cancelado no lo desbloqueaba).
E2E por la superficie pública (boot real con CSRF, job ejecutándose,
webhook firmado 200 / mal firmado 401, SIGTERM limpio) + lane requerida
jobs-redis con Redis 7 real. NU7-1..4 y QM7-1 (showcase re-pinado con
guard de pins contra el último tag publicado EN VIVO + smoke por HTTP en
el gate requerido). **quark v1.3.3:** quark#252 cerrado por implementación
de raíz — la tx implícita de Create/Update bajo RLS nativo se acota a la
operación (la sonda contra PG real mostró 11 sesiones idle-in-transaction
= exactamente los 11 Create; DDL posterior bloqueado; read-your-writes
roto): sin retención hasta el fin del ctx, DDL en ms con ctx vivo, write
visible en el propio ctx; el executor devuelve la conexión al pool incluso
en pánico del driver (QK7-1, con detalle fino de los RLocks internos de
database/sql); errores ya no enmascarados como ErrNoRows en QueryRow
(QK7-3, driver interno que acuña rows-con-error); lane -race en CI con los
2 tests de batch acotados (QK7-2). **orbit v1.4.4 (+ agent/v0.5.4,
server/v0.8.4, quarkbridge/v0.3.4, quarkdatasource/v0.2.6):** sospecha de
auth POR ENDPOINT — un frame aceptado en A ya no resetea la evidencia de B
(OR7-2, test determinista ciclo a ciclo); guard de contenido de release
notes (OR7-1) y linter que veta IDs de hallazgo en el sitio (OR7-3);
requires de nucleus v1.4.0 y quark v1.3.3 en TODOS los módulos y el pin
del root de quarkdatasource actualizado (QM7-6). **Paraguas:** guard de
sincronía de sidebars espejadas disparando también en re-pins vía gitlinks
(QM7-4), comentario veraz en website-ci (QM7-5), regla de IDs de hallazgo
en el linter de lo servido. **quantum-app v0.1.0:** repo nuevo como consumidor
externo REAL de la suite (app warehouse; requires explícitos del set
certificado vía module proxy, JAMÁS workspace — guard GOWORK probado en
negativo en CI), con E2E Docker 7/7 de la banda nunca-ejecutada del §4:
sesiones Redis reales, S3 contra MinIO, SMTP real (Mailpit), outbox
transaccional sobre PG con bridge webhook, cadena
quark→quarkbridge→panel orbit con feed vivo por el bus, multi-base
PG+MySQL por alias y RÉPLICA física de PG (streaming) vía WithReplicas de
quark. El estreno de S3 cazó un bug real de nucleus (isS3NotFound compara
por texto y nunca mapea ErrNotFound contra un endpoint real — issue
abierto), más una observación del carril HTTP del live feed de orbit y un
papercut del payload base64 del bridge webhook (issues abiertos, 8ª
pasada). suite-manifest.yaml con denominador GENERADO desde los
inventarios de los 3 productos a los tags pinados: 789 ítems — 67
covered con evidencia puntual, 552 not-covered con razón, 170
out-of-scope — y gate que falla ante ítems sin clasificar, huérfanos y
pin drift (probado en negativo; el drift real del bump al set 1.8.0 lo
cazó en producción). Tren de
releases en orden de dependencias con el procedimiento nuevo QM7-3: el
tag de suite se corta DESPUÉS del último PR de la ronda. Las 3 secciones
de release notes de producto se redactaron sobre los release PRs (el
guard de contenido las exigió — funcionando como diseñado).

--- Quantum 1.7.2 (histórico) --- cierre de la 6ª ronda: un arco normal de subversiones (la
6ª auditoría CONFIRMÓ la certificación 1.7.1 sin P0/P1 nuevos) que cierra
su banda de P2/P3 y ejecuta de una vez la documentación de producto
pendiente desde la 4ª. La lección aplicada: la rama que nunca se ejecutó —
cada fix llegó con el test o la lane que lo habría cazado. **nucleus
v1.3.3:** NU6-1 — CRUD.Create descartaba en silencio toda PK asignada por
la aplicación (SQLite insertaba fila con PK NULL SIN error; UUIDs de
cliente imposibles): la PK no-cero viaja en el INSERT sin read-back ni
backfill, pineado rojo/verde contra SQLite, PG y MSSQL reales. NU6-2 —
ErrNoPrimaryKey explícito en las ops por id y ORDER BY sobre columna real.
NU6-3 — TOP 1 en createuser/changepassword, fail-fast del session store
SQL y el outbox en mssql/oracle (incluidos dos puentes que lo anulaban), y
compatibilidad acotada por subsistema con tabla honesta. NU6-4 — «not
null» estricto: db:"not null unique" ya no pierde el unique en silencio.
**quark v1.3.2:** QK6-2 — la adquisición de conexión del RLS nativo era
incancelable (pool saturado = goroutine colgado más allá del deadline):
db.Conn(ctx) + tx desacoplada, con pin de no-fuga del pool. QK6-3 — el
commit diferido fallido deja log a nivel Error y contador
(Client.DeferredCommitFailures); semántica de escritura documentada donde
el lector la ve. QK6-1 — segundo anillo de tests de motor en lanes
(MariaDB Otel/Stress, patas all-engines con skip visible, locks de Redis
contra Redis REAL por primera vez) e inventario con cero huérfanos sin
clasificar. **orbit v1.4.3 (+ agent/v0.5.3, server/v0.8.3,
quarkbridge/v0.3.3, quarkdatasource/v0.2.5):** OR6-1 — require_connection
se daba por bueno con token inválido (la sonda /healthz exenta de auth
cerraba Connected()): la señal es ahora el primer frame aceptado bajo
auth, E2E con binarios reales (token malo = boot FALLA). OR6-2 — WARN de
sospecha de auth tras 3 ciclos sin frame aceptado (el 401 que la carrera
de transporte se tragaba). QM6-1 — requires cross-repo alineados y regla
de DISCLOSURE en el manifest-guard §5: un require rancio no declarado en
declared_lags rompe el CI. **Docs (Fase 3, los tres productos):**
Deployment, Security, Upgrade guide, FAQ y release notes publicadas en el
sitio; la Configuration reference de nucleus se GENERA por script desde su
registry con gate de frescura en CI (el drift es imposible); sidebars
curadas estilo Django/Laravel; sitio íntegro en inglés (QADR-0007,
reversible); CLAUDE.md de los 4 repos sin fósiles y bajo guard. El corte
del root de orbit se forzó con el footer Release-As (sus commits eran
docs/ci): desviación documentada en el informe de cierre. Verificación del
set: manifest-guard completo (§1-§5), build de los 9 patrones, sitio
construido y linteado sobre lo SERVIDO sin exclusiones, nucleus new pina
v1.3.3, go install @v0.8.3 con caché virgen.

--- Quantum 1.7.1 (histórico) --- cierre de la 5ª ronda de auditoría, verificado por ejecución
real (Docker) y con la lección de la ronda instalada como forcing functions:
cada versión hardcodeada queda gestionada por release-please o vigilada por
un check de CI. **orbit v1.4.2 (+ server v0.8.2, agent v0.5.2,
quarkdatasource v0.2.4):** OR5-1 — server/v0.8.1 pinaba agent v0.5.0 (sin el
fix OR-2) y su propio test de regresión fallaba standalone; barrido completo
de pins internos + CI que ahora EJECUTA tests con GOWORK=off en los 6
módulos + check_internal_pins.sh (pin de hermano == último tag; probado en
negativo). OR5-2 — un token de agente rechazado era un fallo 100% silencioso
(la sonda /healthz «conectaba», el 401 del stream solo salía en Debug, el
backoff se reseteaba): WARN rate-limited en agente y server (con IP), el
backoff solo se resetea tras el primer frame aceptado, y el INFO «connected»
solo se emite con la aceptación real; E2E con binarios reales: intervalos
crecientes ~1.4s→10.6s y cero «connected» falsos. **nucleus v1.3.2:** NU5-1
— la web enseñaba una sintaxis de tags db: que el parser ignoraba en
silencio; página reescrita, db:"-" implementado (exclusión real del campo),
WARN de arranque ante directivas desconocidas y regla en bodycheck que
valida los tags de los snippets contra el parser real. NU5-2 — el camino
RETURNING/OUTPUT asumía PK entera y existente (PK UUID rompía el Create en
PG; sin PK, 42703): solo se emite con PK declarada y entera. NU5-4 — la
rama MSSQL jamás se había ejecutado, y al ejecutarla afloró que el listado
CRUD emitía LIMIT (inválido en T-SQL): paginación OFFSET…FETCH/TOP 1 y lane
MSSQL corriendo TODO TestCRUDLive_ contra SQL Server real. NU5-3 — el
scaffold pinaba v1.3.0: la constante la gestiona release-please y la vigila
CI (nucleus new demo pina ahora el tag recién cortado). NU5-5 — el evento
insert reporta las filas reales también en el camino RETURNING. **quark
v1.3.1:** QK5-1 — cadenas mixtas de set-ops divergían en silencio por motor
(precedencia de INTERSECT): ErrUnsupportedFeature. QK5-4 — seis tests de
integración vivían fuera de toda lane; al entrar en la matriz, el de RLS
nativo destapó un cuelgue de locks y una PÉRDIDA SILENCIOSA de escrituras
(INSERT…RETURNING bajo RLS nativo se rollbackeaba al cancelarse el ctx):
ciclo de vida de la tx desacoplado con WithoutCancel, regresión pineada
rojo/verde contra PG real. **Paraguas:** QM5-1 — el sitio publicado servía
por defecto snapshots viejos con jerga: lastVersion current con el tag real,
cola de snapshots curada (último patch por minor de 1.x, limpiados en sus
repos fuente) y linter post-build sobre el HTML SERVIDO, sin exclusiones.
QM5-3 — las docs de orbit decían v1.2.1 (real v1.4.1): coherencia de versión
con marcador + check en CI (orbit era el único repo sin él). Fase 4:
manifest-guard ampliado (§3 los 5 tags de módulo de orbit contra el pin —
disparó en producción durante la propia ronda al cortarse agent/v0.5.2 —,
§4 tabla del README == manifiesto), job go-install-tag con caché virgen, e
inventario de versiones hardcodeadas en los 4 repos con 3 rancios extra
cerrados. Verificación del set: manifest-guard completo, build de los 9
patrones del workspace, tests standalone por módulo, sitio construido y
linteado sobre lo servido; release-please cortó quark v1.3.1, nucleus
v1.3.2, orbit v1.4.2 + agent/v0.5.2 + server/v0.8.2 + quarkdatasource/v0.2.4.

--- Quantum 1.7.0 (histórico) --- cierre de la 4ª reauditoría, verificado por EJECUCIÓN real
con Docker (no por lectura de código): la matriz de motores que las cuatro
auditorías marcaron como «no verificable sin Docker» se corrió de verdad.
**orbit v1.4.1 (+ server v0.8.1, agent v0.5.1, proto v0.4.1):** **OR-1** —
server no compilaba standalone (`server/go.mod` pinaba proto v0.3.0 mientras
el código usaba `adminv1.GetSelfRequest`/`SelfInfo` de v0.4.0; el go.work lo
enmascaraba y `go install .../admin-server@server/v0.8.0` estaba roto).
Alineado el require a proto v0.4.0/agent v0.5.0; los seis módulos pasan
build+vet con GOWORK=off. **OR-2** — el `--agent-token` no viajaba en el
stream bidi (el interceptor era `UnaryInterceptorFunc`, que connect-go no
invoca en streaming → 401 en bucle, telemetría muerta fuera de loopback);
sustituido por un `connect.Interceptor` completo con WrapStreamingClient.
Test de regresión con agente real: rojo sin el fix, verde con él. **Orbit no
tenía CI de build ni test** (solo pages/release-please) — esa es la causa de
que OR-1/OR-2 llegaran a tag; añadido CI de cinco jobs (standalone GOWORK=off
por módulo — habría atrapado OR-1 —, tests, Data Studio contra PG+MySQL
reales, govulncheck, linter de docs). **nucleus v1.3.1:** **bug real de
producción que SQLite ocultaba** — `CRUD.Create` obtenía la PK con
`LastInsertId()`, que pgx/mssql no implementan, así que TODO Create en
Postgres devolvía id 0 y el flujo crear→usar-id operaba sobre 0. Afloró al
correr Data Studio de orbit contra un Postgres real. Corregido con
RETURNING (PG) / OUTPUT INSERTED (MSSQL); Oracle queda como laguna declarada.
Verificado contra PG 16 y MySQL 8 reales. También NU-1 (README decía
pkg/observability «experimental» cuando v1.3.0 lo hizo «stable»; check de
coherencia README↔inventory en CI) y NU-2 (W2 `sql_driver_instrumentation`
documentada). **quark v1.3.0:** matriz de 6 motores en verde por ejecución
(SQLite/PG/MySQL/MariaDB/MSSQL/Oracle) — MERGE upsert + back-fill de PK en
MSSQL, locks de migración (sp_getapplock/DBMS_LOCK/GET_LOCK), introspección,
RLS. Al ejercitar set-ops afloró que `INTERSECT ALL`/`EXCEPT ALL` eran código
inalcanzable (sin métodos públicos): expuestos `IntersectAll`/`ExceptAll`, y
el test cazó que MSSQL no las soporta (emitía SQL inválido en vez de
ErrUnsupportedFeature) y que el godoc negaba INTERSECT/EXCEPT en MariaDB
siendo falso. **Seguridad:** los seis módulos de orbit suben a go1.26.5 y
cierran GO-2026-5856 (fuga de ECH en crypto/tls, alcanzable desde los dials
TLS del agente y del relay Redis); govulncheck limpio en los tres repos.
**Docs de producto:** barrido de jerga interna (ADR/P0/SPEC.md/CLAUDE.md) en
los sitios de los tres repos + linter `check_docs_product_voice.sh` en CI que
lo impide reincidir. Verificación del set: los ocho patrones del workspace
compilan con el pin nuevo (go.work a 1.26.5); CI verde y mergeado en los tres
repos; release-please cortó quark v1.3.0, nucleus v1.3.1 y orbit v1.4.1 (+ los
cinco submódulos). Los tres pines EN TAG exacto.

--- Quantum 1.6.0 (histórico) --- orbit sube a v1.4.0 (+ server v0.8.0, proto v0.4.0): el
backlog de UI del plano fleet ejecutado al completo (orbit#70–#74, decisión
de Carlos «todas»). **#71** barra de filtros en las páginas de stream
(method/path-glob/status-class/sql-model/node) + knob de sampling (el proto
ya lo soportaba y #66 hizo real el sampler); estado debounced/persistido.
**#73** herramientas del audit log: filtro por actor/acción/nodo + rango
temporal, paginación y export CSV, todo client-side sobre el ring completo.
**#72** Data Studio expone lo que el backend ya sabe: multi-select +
BulkAction delete, selector de nodo (threading de node_id), choices→select,
editor de fecha (datetime-local↔RFC3339), FK→link al modelo referenciado.
**#70** (proto+server+UI, ADR aditivo): RPC `ControlService.GetSelf`
(identidad del operador + read_only + versión del server vía
debug.ReadBuildInfo) → el footer muestra «orbit <version> · <subject>
[(viewer)]» y Data Studio esconde las mutaciones en modo read-only. **#74**
(parcial): NodeDetail «Recent activity» ahora es un feed en vivo HTTP+SQL
por nodo (la correlación de node_id se arregló en #66; «Components»
eliminado por honestidad), búsqueda de modelos en el sidebar, y umbral de
sentencia lenta configurable; diferidos i18n, barrido completo de a11y de
tablas, y consolidar las tablas del panel in-process (#74 sigue abierta).
nucleus v1.3.0 y quark v1.2.2 continúan del set 1.5.0. Verificación: los
seis patrones del workspace compilan con el pin nuevo; go test verde en los
tres módulos de orbit; tsc + eslint --max-warnings 0 + vite build verdes;
GetSelf verificado end-to-end por TestServer_GetSelf (server real sobre el
cable). release-please cortó orbit v1.4.0 + server/v0.8.0 + proto/v0.4.0.

--- Quantum 1.5.0 (histórico) --- nucleus sube a v1.3.0: los dos compromisos con fecha del
gate v1.0 de nucleus, vencidos, resueltos (decisiones de Carlos). **W1
(nucleus#207/#208):** pkg/observability + pkg/observability/hooks promovidos
de experimental a stable y congelados — superficie pure-stdlib coherente,
frozen-but-not-firewalled; el freeze fija solo las formas de los símbolos
(los internos pooled/ring-buffer siguen optimizables). **W2
(nucleus#206/#210, ADR-021):** instrumentación SQL a nivel de driver opt-in
(`sql_driver_instrumentation`): un wrapper de database/sql/driver lleva al
feed en vivo las sentencias directas db.QueryContext/ExecContext que esquivan
model.CRUD (outbox, session stores SQL, migraciones, SQL crudo),
de-duplicadas contra CRUD por un marcador de contexto; off por defecto → coste
cero en el hot path. Los dos observers coexisten porque el wrapper no conoce
el ModelName. El gate v1.0 de nucleus queda con W1 y W2 cerrados. quark
v1.2.2 y orbit v1.3.0 continúan del set 1.4.0. Verificación: los seis
patrones del workspace compilan con el pin nuevo; CI de nucleus verde en
ambos PRs (freeze rebaselinado, firewall, matriz de 5 motores incl. el test
live del wrapper contra postgres/mysql, compat, smoke); release-please cortó
v1.3.0 con ambos feats en el CHANGELOG.

--- Quantum 1.4.0 (histórico) --- orbit sube a v1.3.0 (+ server v0.7.0, agent
v0.5.0): la ejecución del backlog de la auditoría de orbit
(orbit#66/#67/#68/#69). El reconocimiento del brief: el plano fleet es REAL de
punta a punta; los problemas eran dos botones fake, un audit roto bajo auth,
dos bugs
de telemetría fleet y UX incipiente. **Plano fleet (server v0.7.0 +
agent v0.5.0, orbit#66)**: el filtro agregado se reanuda al reconectar
un agente (State.OnAgentSubMode estaba sin cablear → pérdida silenciosa
de telemetría); los eventos viajan con el NodeID registrado del agente
(antes el del bus in-process → tarjetas por nodo a 0 con tráfico real);
el sampling_rate por suscripción SE APLICA en el fanout (residual
rate/aggRate) y el Subscribe agregado propaga el máx por tipo;
GetSnapshot deja de ser stub (providers GO_RUNTIME/REGISTERED_MODELS);
operador read-only (X-Auth-Role: viewer / --ui-read-only → mutaciones
de Data Studio PermissionDenied); CSP+nosniff+X-Frame-Options; lockout
de credenciales por IP; IdleTimeout h2c; expiración de agentes
inactivos (janitor MarkStale + revive en Touch). **Panel in-process
(orbit v1.3.0, orbit#67)**: el auditMiddleware colgaba solo del branch
SPA GET-only → bajo auth las escrituras de Data Studio no se auditaban;
redacción del OldValue; lockout de login; gate CSRF de Content-Type;
headers de seguridad; DELETE /api/sessions/{token} real (el botón
«terminate» de la SPA fallaba en cada click) y export alineado a
/api/exports (la SPA llamaba rutas inexistentes → 404). **UX de la SPA
fleet (orbit#68)**: toasts aria-live, feedback de error en Data Studio,
pausa con buffer, pantalla de no-autorizado, a11y del modal, contraste
WCAG del token t26. **Docs (orbit#69)**: versiones, «esqueleto» falso
corregido, aviso de superusuario + knobs read-only + guía OIDC en el
sitio, identidad de nodo, rutas de la SPA. Diferidos → issues
orbit#70–#74. Nucleus v1.2.0 y quark v1.2.2 continúan del set anterior
sin cambios; proto queda v0.3.0 (el contrato no cambió). Verificación:
los seis patrones del workspace compilan con el pin nuevo;
`go install …/server/cmd/admin-server@v0.7.0` → --version v0.7.0
(buildinfo end-to-end, con los flags nuevos); `go test ./...` verde en
raíz/agent/server sobre el main fusionado; govulncheck 0/8 (12ª sesión,
mismo día).
