# Verificación dirigida de cierre — Arco de endurecimiento #1, parte (a)

**Qué cubre.** La evidencia MECÁNICA del punto **(a)** que solicita
[`CIERRE_ENDURECIMIENTO_1.md`](CIERRE_ENDURECIMIENTO_1.md): que **SEC-1** y
**SEC-2** no dejan vivo ningún camino de auth débil. Para cada uno se muestra el
código certificado en VERDE (la puerta débil está muerta) y, reintroduciendo el
anti-patrón, el negativo en ROJO (el guard lo caza).

**Qué NO cubre.** El punto **(b)** del cierre —que B.1/B.2 no generan falsos
positivos en la lane semanal normal— es juicio del revisor y queda a su firma;
esta nota no lo sustituye.

**Reproducible.** Todo se ejecutó sobre `quantum-app` en el tag **v0.1.2** (el
del set certificado Quantum 1.10.0), en un worktree desechable. Los parches del
anti-patrón NO se comitearon; se revirtieron tras capturar el rojo. Para
re-ejecutar:

```bash
git clone https://github.com/jcsvwinston/quantum-app && cd quantum-app
git checkout v0.1.2
# baseline verde:
GOWORK=off go test ./cmd/quantum-app/ -run TestValidateDeploymentSecret -v
GOWORK=off go test ./internal/warehouse/ -run TestOutboxHookRequiresSignature -v
# el rojo: aplicar cada anti-patrón de abajo, re-correr el test, revertir.
```

---

## (a1) · SEC-1 — el secreto de despliegue es fail-closed

**Puerta:** `validateDeploymentSecret` (núcleo unit-testable de `mustEnv`);
`cmd/quantum-app/main.go`. Test: `TestValidateDeploymentSecret`.

### VERDE — código certificado (v0.1.2)

```
$ GOWORK=off go test ./cmd/quantum-app/ -run TestValidateDeploymentSecret -v
--- PASS: TestValidateDeploymentSecret
    --- PASS: /unset_is_rejected
    --- PASS: /empty_is_rejected
    --- PASS: /dev_outbox_secret_example_value_is_rejected
    --- PASS: /dev_outbox_token_example_value_is_rejected
    --- PASS: /warehouse-ops_example_value_is_rejected
    --- PASS: /a_real_operator-provided_value_is_accepted
ok  github.com/jcsvwinston/quantum-app/cmd/quantum-app        # EXIT=0
```

Sin la env → error «must be set»; con un valor-ejemplo público del repo
(`dev-outbox-secret`, `dev-outbox-token`, `warehouse-ops`) → error «example»;
solo un valor real de operador pasa. `mustEnv` convierte ese error en
`log.Fatalf` al arranque: el proceso muere en vez de arrancar sobre una
credencial pública.

### ROJO — anti-patrón reintroducido (fail-open sobre los valores-ejemplo)

Parche en `validateDeploymentSecret` (se retira la comprobación de
`exampleSecretValues`, emulando el `envOr("WAREHOUSE_OUTBOX_SECRET",
"dev-outbox-secret")` + sin validación del estado pre-fix):

```go
-	if what, ok := exampleSecretValues[value]; ok {
-		return fmt.Errorf("%s is set to %q — %s, not a secret...", key, value, what)
-	}
-	return nil
+	_ = exampleSecretValues // anti-patrón: no se rechazan los valores-ejemplo
+	return nil
```

```
$ GOWORK=off go test ./cmd/quantum-app/ -run TestValidateDeploymentSecret -v
--- FAIL: TestValidateDeploymentSecret
    --- PASS: /unset_is_rejected
    --- PASS: /empty_is_rejected
    --- FAIL: /dev_outbox_secret_example_value_is_rejected
    --- FAIL: /dev_outbox_token_example_value_is_rejected
    --- FAIL: /warehouse-ops_example_value_is_rejected
    --- PASS: /a_real_operator-provided_value_is_accepted
FAIL github.com/jcsvwinston/quantum-app/cmd/quantum-app        # EXIT=1
```

**Lectura:** con el anti-patrón, `dev-outbox-secret` (el secreto HMAC público de
`config/e2e.yaml`) y los otros dos valores-ejemplo son ACEPTADOS → el arranque
procedería sobre una credencial que vive en el árbol. El guard (test) lo caza.
Con el fix, esos tres casos se rechazan. **Puerta débil muerta.**

---

## (a2) · SEC-2 — `/hooks/outbox` exige la firma HMAC del cuerpo, sin downgrade

**Puerta:** `authenticateOutboxDelivery`; `internal/warehouse/handlers_orders.go`.
Test: `TestOutboxHookRequiresSignature`.

### VERDE — código certificado (v0.1.2)

```
$ GOWORK=off go test ./internal/warehouse/ -run TestOutboxHookRequiresSignature -v
--- PASS: TestOutboxHookRequiresSignature
    --- PASS: /valid_body_signature_is_accepted
    --- PASS: /no_signature_header_is_rejected
    --- PASS: /no_signature_but_a_would-be_legacy_token_is_still_rejected
    --- PASS: /garbage_signature_is_rejected
    --- PASS: /signature_under_the_wrong_secret_is_rejected
    --- PASS: /body_tampered_by_one_byte_is_rejected
ok  github.com/jcsvwinston/quantum-app/internal/warehouse       # EXIT=0
```

Firma válida sobre el cuerpo exacto → 200; sin cabecera de firma → 401 aunque
lleve un `X-Outbox-Token`; firma basura / bajo secreto equivocado / cuerpo +1
byte → 401. La firma se compara con `hmac.Equal` (tiempo constante).

### ROJO — anti-patrón reintroducido (downgrade al token estático)

Parche en `authenticateOutboxDelivery` (cuando falta la firma, se acepta un
token compartido):

```go
	if sig == "" {
-		return false
+		return r.Header.Get("X-Outbox-Token") == "dev-outbox-token" // downgrade
	}
```

```
$ GOWORK=off go test ./internal/warehouse/ -run TestOutboxHookRequiresSignature -v
    handlers_orders_auth_test.go:80: no signature but a would-be legacy token
        is still rejected: status 200 (want 401)
--- FAIL: TestOutboxHookRequiresSignature
    --- PASS: /valid_body_signature_is_accepted
    --- PASS: /no_signature_header_is_rejected
    --- FAIL: /no_signature_but_a_would-be_legacy_token_is_still_rejected
    --- PASS: /garbage_signature_is_rejected
    --- PASS: /signature_under_the_wrong_secret_is_rejected
    --- PASS: /body_tampered_by_one_byte_is_rejected
FAIL github.com/jcsvwinston/quantum-app/internal/warehouse      # EXIT=1
```

**Lectura:** con el downgrade, una entrega SIN cabecera de firma pero con el
token compartido conocido pasa la auth y llega a **200** — exactamente el camino
débil que SEC-2 elimina. Con el fix, ese caso es **401**. La fuerza de la puerta
no colapsa a `min(HMAC, token)`. **Puerta débil muerta.**

---

## Conclusión de (a)

| Sub-punto | Puerta certificada | Anti-patrón reintroducido |
|---|---|---|
| **(a1) SEC-1** | secreto-ejemplo/vacío rechazado; boot muere | secreto público ACEPTADO → **rojo** |
| **(a2) SEC-2** | sin firma → 401 (aun con token) | sin firma + token → **200** → **rojo** |

Los dos negativos están vivos y muerden: reintroducir el default público o el
downgrade al token pone los tests en rojo; el código certificado los mantiene en
verde. **No queda ningún camino de auth débil vivo por SEC-1/SEC-2.** El punto
**(b)** (falsos positivos de B.1/B.2 en la lane semanal) sigue pendiente de la
revisión humana.
