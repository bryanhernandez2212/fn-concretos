# Rastreo en vivo de flota — versión web

**De:** Dirección / app móvil (Flutter) — pantallas "Rutas activas" y "Ubicación en vivo"
**Para:** Equipo web (React)
**Backend:** operaciones-service (sin cambios)

## 1. Qué hay que construir

Un mapa que muestra, en tiempo casi-real, dónde están las revolvedoras/bombas que ya salieron de planta — con su ícono apuntando en la dirección en que avanzan y una línea mostrando por dónde ya pasaron.

Ya existe en la app móvil. La lógica de datos es idéntica para web; lo único que cambia es la librería de mapas y cómo se dibuja el marcador.

## 2. El backend ya está listo — no pidan nada nuevo

Son los mismos endpoints REST que ya usa la app móvil, nada específico de Flutter:

| Método | Endpoint | Para qué |
|---|---|---|
| `GET` | `/remisiones` | Lista de remisiones. Sin filtro trae todas; filtren en el cliente por estatus `salio_planta / en_camino / proximo_llegar / en_obra / descargando` para la vista de flota completa. |
| `GET` | `/remisiones/{id}/ruta` | Posición actual + `historial` de puntos GPS de esa remisión. Este es el que alimenta al mapa — pídanlo cada 15s por cada remisión activa. |

**Antes de empezar:** confirmen con backend que operaciones-service tiene CORS habilitado para el dominio del dashboard web. Es lo primero que va a fallar si no está.

## 3. Maps JavaScript API, no Navigation SDK

En el móvil se usa el Navigation SDK de Google porque el conductor también navega turn-by-turn. Aquí solo van a **mostrar** ubicaciones — con la Maps JavaScript API normal alcanza y de sobra.

Librería recomendada: `@vis.gl/react-google-maps` (la mantiene Google). Necesitan una API key con "Maps JavaScript API" habilitada — puede ser el mismo proyecto de GCP, solo agreguen ese servicio; no toquen ni paguen el Navigation SDK.

## 4. Flujo de datos: poll cada 15s, no WebSocket

Un `setInterval` por remisión activa, mismo intervalo que usa la app móvil para que ambas vistas queden consistentes con el mismo dato.

```js
// hooks/useRutaRemision.js
function useRutaRemision(remisionId, token) {
  const [ruta, setRuta] = useState(null);

  useEffect(() => {
    let cancelado = false;

    async function poll() {
      const res = await fetch(
        `${BASE_URL}/remisiones/${remisionId}/ruta`,
        { headers: { Authorization: `Bearer ${token}` } }
      );
      const data = await res.json();
      if (!cancelado) setRuta(data); // { posicionActual, historial }
    }

    poll();
    const id = setInterval(poll, 15_000);
    return () => { cancelado = true; clearInterval(id); };
  }, [remisionId, token]);

  return ruta;
}
```

## 5. Rumbo del ícono: el backend no lo manda

Ni `RutaRemisionResponse` ni el ping de GPS traen un ángulo de rumbo. Se calcula en el cliente con los dos últimos puntos del `historial` — exactamente igual que hace la app móvil.

```js
// lib/bearing.js
function bearingBetween(p1, p2) {
  const toRad = d => (d * Math.PI) / 180;
  const toDeg = r => (r * 180) / Math.PI;
  const dLon = toRad(p2.lng - p1.lng);
  const y = Math.sin(dLon) * Math.cos(toRad(p2.lat));
  const x =
    Math.cos(toRad(p1.lat)) * Math.sin(toRad(p2.lat)) -
    Math.sin(toRad(p1.lat)) * Math.cos(toRad(p2.lat)) * Math.cos(dLon);
  return (toDeg(Math.atan2(y, x)) + 360) % 360;
}
```

**Detalle que importa:** si el `historial` todavía no tiene suficientes puntos para calcular un nuevo rumbo, mantengan el último valor calculado — no lo regresen a 0°/norte. Así se comporta el ícono nativo y evita que el camión "salte" de dirección entre polls.

## 6. Marcador rotado y línea de trayecto

- Marcador: un `AdvancedMarker` con un `<div>`/SVG propio, rotado por CSS con `transform: rotate(${bearing}deg)`. En web no hace falta registrar un bitmap por color de ruta como en nativo — basta con cambiar el `fill` del SVG.
- Trayecto recorrido: un `Polyline` alimentado con el arreglo completo de `historial`.

## 7. Un solo mapa para toda la flota

Para la vista tipo "Rutas activas" (todos los camiones a la vez): un solo `<Map>` con N marcadores, no N mapas. Al llegar datos nuevos actualicen la posición de cada marcador — no desmonten ni recreen el mapa, o van a perder el zoom/posición de cámara del usuario en cada refresh.

## Checklist para el equipo

- [ ] API key nueva o reutilizada con "Maps JavaScript API" — no Navigation SDK.
- [ ] CORS confirmado en operaciones-service para el dominio del dashboard.
- [ ] Mismo bearer token / header `Authorization` que ya usa auth-service.
- [ ] Poll de 15s por remisión activa — no WebSocket, no menor a 15s.
- [ ] Rumbo calculado en cliente, con retención del último valor si falta historial.
- [ ] Un mapa persistente con marcadores actualizables, no un mapa por remisión ni recreación en cada poll.
