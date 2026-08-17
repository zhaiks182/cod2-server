# CoD2 Dedicated Server (Linux) — Instalación + Mod ZPAM 4.08 Custom (Score Popup + Blood FX)

Guía completa para levantar un servidor dedicado de **Call of Duty 2** en Linux
(Ubuntu) usando `cod2_lnxded` + `libcod`, corriendo como servicio systemd, con
el mod **zPAM 4.08** y dos features custom (score popup + blood FX) agregadas
sobre el mod original.

Probado en: **Ubuntu 24.04 LTS**, arquitectura `amd64` con soporte `i386`.

## Índice

1. [Prerrequisitos del sistema](#1-prerrequisitos-del-sistema)
2. [Estructura de archivos del servidor](#2-estructura-de-archivos-del-servidor)
3. [Archivos a preparar: propios del repo vs. copiados por FTP](#3-archivos-a-preparar-propios-del-repo-vs-copiados-por-ftp)
4. [Script de arranque (`start_libcod.sh`)](#4-script-de-arranque-start_libcodsh)
5. [Servicio systemd](#5-servicio-systemd)
6. [Configuración básica (`server.cfg`)](#6-configuración-básica-servercfg)
7. [Mod ZPAM 4.08 — Custom Features (Score Popup + Blood FX)](#7-mod-zpam-408--custom-features-score-popup--blood-fx)

---

## 1. Prerrequisitos del sistema

`cod2_lnxded` es un binario de 32 bits, así que en un sistema `amd64` moderno
hace falta habilitar la arquitectura `i386` antes de instalar sus
dependencias.

### 1.1. Prerrequisitos de CoD2

```bash
sudo dpkg --add-architecture i386
sudo apt-get update
sudo apt-get -y install libstdc++5:i386
```

### 1.2. Prerrequisitos de libcod

[`libcod`](https://github.com/xtnded/libcod) (aquí en su fork `libCoD2x.so`,
usado vía `LD_PRELOAD`) extiende el server con más comandos/cvars de consola y
soporte para mods como zPAM. El binario ya compilado (`libCoD2x.so`) viene
incluido en este repo (sección 3.1) — igual hacen falta estas librerías de
32 bits para poder correrlo:

```bash
sudo apt-get -y install gcc-multilib
sudo apt-get -y install libmysqlclient-dev:i386
sudo apt-get -y install g++-multilib
```

---

## 2. Estructura de archivos del servidor

Todo el servidor vive bajo un solo `fs_homepath`. En este caso:

```
/home/gameserver/1.3/puG/
├── cod2_lnxded              # Binario dedicado del server (32-bit)
├── libCoD2x.so               # libcod, cargado vía LD_PRELOAD
├── start_libcod.sh           # Script de arranque
├── start_server.sh           # Wrapper viejo (screen) - no se usa, queda systemd en su lugar
└── main/                     # fs_game "base" (assets del juego + mod)
    ├── iw_00.iwd ... iw_15.iwd                # Assets base del juego (~1.9 GB)
    ├── localized_english_iw00.iwd ... iw11.iwd # Localización EN
    ├── iw_CoD2x_01.iwd                         # Assets de libcod/CoD2x
    ├── zpam_maps_v7.iwd                        # Pack de mapas del mod
    ├── zpam408.iwd                             # Mod zPAM 4.08 (+ features custom, ver sección 7)
    ├── server.cfg                              # Config del server (gametype, rcon, cvars de zPAM)
    ├── config_mp_server.cfg                    # Config autogenerada por el engine (no tocar a mano)
    └── games_mp.log                            # Log de eventos de partida (kills, conexiones, etc.)
```

Notas:

- Los `iw_XX.iwd` y `localized_english_iw*.iwd` son los assets originales del
  juego (no vienen incluidos en este setup — son propiedad de Activision, hay que
  copiarlos desde una instalación legítima de CoD2, ver sección 3).
- `main/` funciona como `fs_basepath`/`fs_game` a la vez en este setup
  (`fs_game` vacío en `start_libcod.sh`, ver sección siguiente): todo vive en
  la raíz de `main/`.
- `sv_wwwBaseURL` en `server.cfg` apunta a un servidor HTTP propio
  (`http://<ip>/cod2/`) para que los clientes descarguen `zpam_maps_v7.iwd` y
  `zpam408.iwd` sin saturar el ancho de banda del server de juego.

---

## 3. Archivos a preparar: propios del repo vs. copiados por FTP

Para levantar el server necesitás dos grupos de archivos distintos: los
propios de este repo (binario, mod, mapas, config), que se obtienen con
`git clone`, y los assets base originales del juego, que tenés que copiar
aparte desde tu propia instalación de CoD2.

### 3.1. Clonar este repositorio

Este repo incluye todo lo necesario salvo los assets base del juego:

| Archivo | Ruta en el server | Qué es |
|---|---|---|
| `cod2_lnxded` | `/home/gameserver/1.3/puG/cod2_lnxded` | Binario dedicado del server (headless) |
| `libCoD2x.so` | `/home/gameserver/1.3/puG/libCoD2x.so` | libcod, cargado vía `LD_PRELOAD` (sección 1.2) |
| `start_libcod.sh` | `/home/gameserver/1.3/puG/start_libcod.sh` | Script de arranque (sección 4) |
| `main/server.cfg` | `/home/gameserver/1.3/puG/main/server.cfg` | Config propia (gametype, rcon, cvars zPAM) |
| `main/zpam408.iwd` | `/home/gameserver/1.3/puG/main/zpam408.iwd` | Mod, con las custom features (sección 7) |
| `main/zpam_maps_v7.iwd` | `/home/gameserver/1.3/puG/main/zpam_maps_v7.iwd` | Pack de mapas oficial del mod (~178 MB) |

`main/zpam_maps_v7.iwd` pesa más de 100 MB, así que este repo usa
**[Git LFS](https://git-lfs.com/)** para poder versionarlo. Instalalo antes
de clonar (una sola vez por máquina):

```bash
# Debian/Ubuntu
sudo apt-get install git-lfs
git lfs install
```

Y luego cloná normalmente — Git LFS baja el contenido real de los `.iwd`
de forma transparente:

```bash
git clone https://github.com/zhaiks182/cod2-server.git
```

Vas a terminar con la misma estructura de carpetas que en la sección 2
(`cod2_lnxded`, `libCoD2x.so`, `start_libcod.sh`, `main/...`), lista para
copiar tal cual al server (por `scp -r`/`rsync`, o clonando directo en el
server si tiene salida a internet).

> ⚠️ GitHub LFS en cuentas gratuitas tiene cuota de **1 GB de banda por
> mes**. Como `zpam_maps_v7.iwd` pesa ~178 MB, alcanza para unos 5-6
> `git clone` por mes antes de que GitHub empiece a rechazar las descargas
> LFS hasta el mes siguiente (o hasta comprar más cuota). Si esto es un
> problema, están disponibles como asset de un [Release](../../releases) en
> un único `.zip`, que no consume esa cuota de LFS.

### 3.2. Archivos que copiás por FTP desde tu instalación de CoD2

Los assets base del juego (`iw_00.iwd` … `iw_15.iwd`,
`localized_english_iw*.iwd`) son propiedad de Activision y pesan ~1.9 GB en
total — no vienen con este repo, hay que copiarlos desde tu propia
instalación legítima de CoD2 (carpeta `main/` del juego original) directo a
la carpeta `main/` del server, **al mismo nivel** que `server.cfg` y
`zpam408.iwd`:

- `iw_00.iwd` … `iw_15.iwd`
- `localized_english_iw00.iwd` … `localized_english_iw11.iwd`
- `iw_CoD2x_01.iwd` (viene con libcod)

Usá un cliente FTP/SFTP (FileZilla, WinSCP, etc.) apuntando a la IP del
server, conectando por SFTP con la misma llave/usuario SSH que ya tengas
configurado, y subí esos archivos a:

```
/home/gameserver/1.3/puG/main/
```

---

## 4. Script de arranque (`start_libcod.sh`)

`/home/gameserver/1.3/puG/start_libcod.sh`:

```bash
#!/bin/bash

sv_maxclients="30"
#fs_game="dtNriflesDM"
fs_homepath="/home/gameserver/1.3/puG"
cod="/home/gameserver/1.3/puG/cod2_lnxded"
com_hunkMegs="256"
config="server.cfg"
cracked="1"
net_port="28960"


args=\
"+set fs_homepath \"$fs_homepath\" "\
"+set sv_cracked $cracked "\
"+set fs_game $fs_game "\
"+set net_port $net_port "\
"+set com_hunkMegs $com_hunkMegs "\
"+set sv_maxclients $sv_maxclients "\
"+set fs_basepath \"$fs_homepath\" "\
"+exec $config"

LD_PRELOAD="/home/gameserver/1.3/puG/libCoD2x.so" $cod $args +set g_gametype sd +map mp_toujane_fix +set rcon_password pug2026! +map_rotate
```

Puntos clave:

- `LD_PRELOAD` es lo que inyecta `libCoD2x.so` en el proceso del server —
  sin esto, zPAM no funciona (usa comandos/cvars extendidos que libcod
  agrega).
- `fs_game` queda vacío (comentado arriba) — todo el contenido (mod incluido)
  se sirve desde `main/`, no desde una carpeta de mod separada.
- `sv_cracked "1"` es necesario para correr el binario sin el launcher
  original de Steam/CD-key.
- El mapa/gametype inicial y el `rcon_password` se pasan como argumentos
  extra al final; `+map_rotate` arranca la rotación definida en `server.cfg`.

Dale permisos de ejecución:

```bash
chmod +x /home/gameserver/1.3/puG/start_libcod.sh
```

---

## 5. Servicio systemd

Para que el server arranque solo al bootear la VM y se reinicie si se cae.

### 5.1. Crear el archivo de servicio

```bash
sudo nano /etc/systemd/system/cod2server.service
```

Contenido:

```ini
[Unit]
Description=Call of Duty 2 Dedicated Server
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=/home/gameserver/1.3/puG
Nice=-20
ExecStart=/bin/bash /home/gameserver/1.3/puG/start_libcod.sh
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

Guardar en nano: `Ctrl + O` → `Enter` → `Ctrl + X`.

> `Nice=-20` le da la máxima prioridad de CPU al proceso (rango válido -20 a
> 19, menor = más prioridad; -20 es el tope). Útil en VMs compartidas para
> minimizar lag del tick del server.

### 5.2. Recargar systemd

```bash
sudo systemctl daemon-reload
```

### 5.3. Habilitar arranque automático

```bash
sudo systemctl enable cod2server.service
```

### 5.4. Iniciar / reiniciar el servidor

```bash
sudo systemctl restart cod2server.service
```

### 5.5. Verificar estado

```bash
sudo systemctl status cod2server.service
```

Debería verse algo así:

```
● cod2server.service - Call of Duty 2 Dedicated Server
     Loaded: loaded (/etc/systemd/system/cod2server.service; enabled; preset: enabled)
     Active: active (running) since ...
   Main PID: 677 (bash)
     CGroup: /system.slice/cod2server.service
             ├─677 /bin/bash /home/gameserver/1.3/puG/start_libcod.sh
             └─680 /home/gameserver/1.3/puG/cod2_lnxded ...
```

Para ver los logs en vivo (kills, conexiones, comandos rcon):

```bash
sudo journalctl -u cod2server.service -f
```

---

## 6. Configuración básica (`server.cfg`)

`main/server.cfg` es donde vive la configuración de gametype/modo/cvars de
zPAM. Se referencia desde `start_libcod.sh` vía `+exec server.cfg`. Ejemplo
mínimo relevante:

```c
// Gametype: sd, dm, tdm, hq, ctf, htf, re, strat
set g_gametype "sd"

// Modo de zPAM (pub | comp | comp_mr3 | comp_2v2 | comp_rifle | comp_lan | ...)
set pam_mode "comp_na"

set sv_hostname "Mi servidor CoD2"
set scr_motd "Welcome. This server is running zPAM 4.08"

set g_password ""          // contraseña del server (vacío = público)
set rcon_password ""       // contraseña de administración remota - NO dejar vacía en producción

// Descarga de mapas/mod vía HTTP en vez de por el protocolo del juego (mucho más rápido)
seta sv_wwwBaseURL "http://<TU_IP>/cod2/"
seta sv_wwwDownload "1"
seta sv_wwwDlDisconnected "0"
```

> ⚠️ **Seguridad**: cambiá `rcon_password` a algo único antes de exponer el
> server a internet — con rcon un atacante puede ejecutar cualquier comando
> de consola del server (kick, ban, cambiar cvars, etc.).

Para que la descarga HTTP (`sv_wwwBaseURL`) funcione, hay que servir
`zpam_maps_v7.iwd` y `zpam408.iwd` desde un webserver (nginx/apache) en la
ruta `/cod2/` de esa IP — no está cubierto en esta guía.

---

## 7. Mod ZPAM 4.08 — Custom Features (Score Popup + Blood FX)

Sobre la base del mod [zPAM 4.08](https://github.com/eyza-cod2/zpam3)
(`zpam408.iwd`), se integraron dos features adicionales sin tocar el
sistema de eventos/scoring original del mod.

### 7.1. Contexto del mod

- CoD2 dedicated server (Linux, `cod2_lnxded` + `libcod`), gametypes: `sd`, `dm`, `tdm`,
  `ctf`, `hq`, `htf`, `re`, `strat`.
- Arquitectura modular: cada feature vive en `maps/mp/gametypes/_<nombre>.gsc` con una
  función `init()`, threadeada una sola vez desde
  `maps/mp/gametypes/global/_init.gsc :: InitModules()`.
- **Sistema de eventos propio** (`maps/mp/gametypes/global/events.gsc`): en vez de pisar
  `_callbacksetup.gsc` (que centraliza fixes de hitbox/daño/logging de todo el mod), los
  módulos se suscriben con `addEventListener("onXxx", ::handler)`. Eventos relevantes:
  `onPlayerDamaged`, `onPlayerKilled`, `onCvarChanged`.
- **Cvars**: se registran con `registerCvar(name, type, default)` /
  `registerCvarEx(method, name, type, default, min, max)`
  (`maps/mp/gametypes/global/cvar_system.gsc`). Para que `level.<cvar>` quede poblado hay
  que registrar un listener `onCvarChanged` **antes** de llamar a `registerCvar` (el
  registro dispara el evento una vez con `isRegisterTime=true`).
- **Reglas por gametype** (`maps/mp/gametypes/rules/<gametype>/<comp|pub>.gsc`): definen
  valores default de cvars vía `ruleCvarDefault(arr, "cvar", valor)`. Es opcional —
  `registerCvar` ya trae su propio default hardcodeado — solo hace falta si querés un
  valor distinto por modo/gametype.
- **Deploy sin repackear**: CoD2 prioriza archivos `.gsc`/assets sueltos en el `fs_game`
  del server por sobre lo empaquetado en el `.iwd`. Se puede iterar rápido con archivos
  sueltos y, cuando está probado, mezclarlos dentro del `.iwd` (con
  `System.IO.Compression.ZipFile` en modo `Update`: `entry.Delete()` + `CreateEntry()`).

Callback real de kill (`_callbacksetup.gsc :: CodeCallback_PlayerKilled`), orden exacto:
`notifyKilling` (puede cancelar el kill) → `notifyKilled` (dispara todos los listeners de
`onPlayerKilled`, entre ellos los nuestros) → `level.onAfterPlayerKilled`
(específico de cada gametype: acá es donde ZPAM realmente asigna
`attacker.score = attacker.pers["score"]`, el valor persistente real).

> ⚠️ Existía un `_callbacksetup.gsc` suelto **viejo/no usado**, de un mod más simple (con
> un addon de airstrike), que pisaba por completo el callback real de ZPAM si llegaba a
> estar en el `fs_game`. Se dejó sin tocar/borrar porque el usuario confirmó que no está
> desplegado, pero si alguna vez aparece un `_callbacksetup.gsc` corriendo que NO tiene el
> sistema de eventos (`level.events`), es señal de que se está usando ese archivo viejo
> por error — rompe silenciosamente decenas de módulos de ZPAM.

### 7.2. Score Popup (`+1` / `+2` / team-kill en rojo)

Basado en: https://killtube.org/showthread.php?1208-plusscore (script standalone, sin
integrar a ningún framework — no aplica cuando lo empaquetás dentro de un mod con su
propio sistema de scoring, ver nota de compatibilidad más abajo).

#### Archivos tocados dentro de `zpam408.iwd`

- **`maps/mp/gametypes/_scorepopup.gsc`** (nuevo) — el módulo completo.
- **`maps/mp/gametypes/global/_init.gsc`** — 1 línea agregada en `InitModules()`:
  `thread maps\mp\gametypes\_scorepopup::init();`
- **`maps/mp/gametypes/rules/sd/comp.gsc`** — 1 línea agregada (opcional, default ya
  viene del módulo):
  `arr = ruleCvarDefault(arr, "scr_scorepopup", 1);`

#### Cvar

`scr_scorepopup` (BOOL, default `1`) — togglable por rcon en caliente, sin reiniciar mapa
(se chequea `level.scr_scorepopup` en cada kill, no solo al registrar).

#### Comportamiento

- HUD element centrado, arriba de la mira, con animación de escala/opacidad (crece y se
  desvanece).
- `+1` kill normal · `+2` headshot o melee · rojo y negativo en team-kill.
- Se salta durante `level.in_readyup` (no muestra puntaje falso cuando en la práctica no
  suma nada realmente) y en gametype `strat` (no tiene score individual).
- ZPAM ya promueve `sMeansOfDeath` a `"MOD_HEAD_SHOT"` para hits en la cabeza (excepto
  con shotgun) en `_callbacksetup.gsc :: CodeCallback_PlayerKilled()`, **antes** de que
  este evento dispare — el módulo solo lee esa clasificación, no la recalcula.

#### ⚠️ Nota de compatibilidad de scoring (importante si se reusa en otro mod)

El script original hace `attacker.score += score` con su propia matemática de bonus. En
ZPAM esto es **inofensivo pero inerte**: cada gametype (`sd.gsc`, `dm.gsc`, `tdm.gsc`,
etc.) pisa `attacker.score = attacker.pers["score"]` de forma incondicional en
`onAfterPlayerKilled()`, que corre **después** de nuestro listener `onPlayerKilled` (ver
orden del callback arriba) — así que cualquier valor que el popup le ponga a `.score`
queda sobrescrito en el mismo frame de servidor, antes de que el cliente lo vea. Si portás
este módulo a un mod SIN ese pisado incondicional de `.score`, hay que sacar la línea
`attacker.score += score;` o vas a duplicar el puntaje real.

#### Código completo

```c
#include maps\mp\gametypes\global\_global;

/*
	Score popup ("+1", "+2" on headshot/melee, red negative on team-kill) shown
	above the crosshair on kill.

	Based on: https://killtube.org/showthread.php?1208-plusscore

	Integrated into ZPAM:
		- Hooked through ZPAM's own event system (onPlayerKilled), instead of
		  overriding _callbacksetup.gsc directly, so all of ZPAM's hitbox/damage/
		  logging code keeps working untouched.
		- Toggleable per server via cvar scr_scorepopup (BOOL, default 1).
		- attacker.score is still touched here (kept from the original script,
		  same +1/+2/team-kill math) but this has no lasting effect on the real
		  scoreboard: every gametype's onAfterPlayerKilled() runs right after this
		  event and unconditionally overwrites .score from attacker.pers["score"]
		  (the value ZPAM actually tracks/persists). So this module is purely a
		  visual layer and can never desync the real score.
*/

init()
{
	// No individual kill score concept in strat
	if (level.gametype == "strat")
		return;

	addEventListener("onCvarChanged", ::onCvarChanged);

	registerCvar("scr_scorepopup", "BOOL", 1); // level.scr_scorepopup

	if (game["firstInit"])
	{
		precacheString(&"");
		precacheString(&"+");
	}

	addEventListener("onPlayerKilled", ::onPlayerKilled);
}

// This function is called when cvar changes value.
// Is also called when cvar is registered
// Return true if cvar was handled here, otherwise false
onCvarChanged(cvar, value, isRegisterTime)
{
	switch (cvar)
	{
		case "scr_scorepopup":
			level.scr_scorepopup = value;
			return true;
	}
	return false;
}

// self = victim (game engine convention for CodeCallback_PlayerKilled)
onPlayerKilled(eInflictor, eAttacker, iDamage, sMeansOfDeath, sWeapon, vDir, sHitLoc, timeOffset, deathAnimDuration)
{
	if (level.scr_scorepopup == 0)
		return;

	// No real score change happens during ready-up practice - don't show a fake one
	if (level.in_readyup)
		return;

	attacker = eAttacker;
	victim = self;

	if (!isDefined(attacker) || !isDefined(victim))
		return;
	else if (!isPlayer(attacker) || !isPlayer(victim))
		return;
	else if (attacker == victim)
		return;

	score = 1;

	// ZPAM already promotes sMeansOfDeath to "MOD_HEAD_SHOT" for head hits (except
	// shotgun) in _callbacksetup.gsc :: CodeCallback_PlayerKilled(), before this
	// event fires - so we just read the classification ZPAM already computed.
	if (isDefined(sMeansOfDeath))
	{
		if (sMeansOfDeath == "MOD_HEAD_SHOT")
			score = 2;
		else if (sMeansOfDeath == "MOD_MELEE")
			score = 2;
	}

	if (isDefined(attacker.pers["team"]) &&
		isDefined(victim.pers["team"]) &&
		attacker.pers["team"] == victim.pers["team"] &&
		level.gametype != "dm")
	{
		score *= -1;
	}

	if (score < 0) score += 1;
	else                 score -= 1;

	attacker.score += score;

	attacker thread plusscore(score + 1);
}


plusscore(score)
{
	if (!isplayer(self))
		return;

	if (!isdefined(self.izno_plusscore)) // first run
	{
		self.izno_plusscore = newClientHudElem2(self);
		self.izno_plusscore.instance = 0;
		self.izno_plusscore.score = score;
		self.izno_plusscore.horzAlign = "center";
		self.izno_plusscore.vertAlign = "middle";
		self.izno_plusscore.alignX = "center";
		self.izno_plusscore.alignY = "middle";
		self.izno_plusscore.x = 0; // middle of screen
		self.izno_plusscore.y = -40; // just above middle of screen
		self.izno_plusscore.alpha = 0.3;
		self.izno_plusscore.fontscale = 0.5;
	}
	else // not first-run
	{
		if (self.izno_plusscore.alpha < 0.3 || self.izno_plusscore.score == 0)
			self.izno_plusscore.alpha = 0.3;
		if (self.izno_plusscore.fontscale < 0.5 || self.izno_plusscore.score == 0)
			self.izno_plusscore.fontscale = 0.5;
		self.izno_plusscore.instance++;
		self.izno_plusscore.score += score;
	}
	if (self.izno_plusscore.score < 0)
	{
		self.izno_plusscore.color = (235/255, 10/255, 10/255); // negative scores are red
		self.izno_plusscore.label = &"";
	}
	else
	{
		self.izno_plusscore.color = (1, 230/255, 125/255); // yellow-ish
		self.izno_plusscore.label = &"+";
	}
	self.izno_plusscore setvalue(self.izno_plusscore.score);

	current_instance = self.izno_plusscore.instance;
	make_bigger = true;
	more_opaque = true;
	steady_opaque_timer = 0;
	alpha_done = false;
	size_done = false;
	while (isdefined(self) && current_instance == self.izno_plusscore.instance && !(alpha_done && size_done))
	{
		if (make_bigger && self.izno_plusscore.fontscale < 2)
			self.izno_plusscore.fontscale += 0.35;
		else if (make_bigger)
			make_bigger = false;
		else if (self.izno_plusscore.fontscale > 2)
			self.izno_plusscore.fontscale -= 0.2;
		else
		{
			size_done = true;
			self.izno_plusscore.fontscale = 1.5;
		}

		if (more_opaque && self.izno_plusscore.alpha <= 0.9) // dont overflow this
			self.izno_plusscore.alpha += 0.1;
		else if (more_opaque && steady_opaque_timer == 20)
			more_opaque = false;
		else if (more_opaque)
			steady_opaque_timer++;
		else if (self.izno_plusscore.alpha >= 0.1) // dont underflow this
			self.izno_plusscore.alpha -= 0.1;
		else
		{
			alpha_done = true;
			self.izno_plusscore.alpha = 0;
		}
		wait 0.05;
	}
	if (!isdefined(self))
		return;
	if (current_instance == self.izno_plusscore.instance)
	{
		wait 0.5;
		if (isdefined(self) && self.izno_plusscore.instance == current_instance)
			self.izno_plusscore.score = 0;
	}
}
```

### 7.3. Blood FX (spray al impactar + "charco" en el piso)

Assets de origen: pack `iw_blood.iwd` (solo contenía `.efx`, **sin ningún script** —
`fx/impacts/flesh_hit.efx` y 6 efectos en `fx/effects/gore/`:
`splats`, `stains`, `stains_lg`, `stains2`, `stains2_lg`, `stains2_big`).

#### Hallazgo clave

Se buscó `loadfx|playfx|_effect\[` en **todo** el mod (todos los `.gsc`, todos los
`maps/mp/mp_<mapa>_fx.gsc`) y no había ninguna referencia a estos assets — ni siquiera al
`flesh_hit.efx` que ZPAM ya traía empaquetado de antes. Es decir, estaban en el `.iwd`
pero **nadie los invocaba**. En CoD2 los efectos de partículas (`fx`) no se disparan solos
por convención de nombre — hace falta `loadfx()` al precache y `playfx()` en el momento
justo, exactamente como hace cada `mp_<mapa>_fx.gsc` con sus propios efectos de mapa
(ejemplo real tomado de `mp_carentan_fx.gsc`):

```c
level._effect["flak_explosion"] = loadfx("fx/explosions/flak88_explosion.efx");
...
playfx(level._effect["flak_explosion"], origin);
```

#### Archivos tocados dentro de `zpam408.iwd`

- **`maps/mp/gametypes/_blood.gsc`** (nuevo) — el módulo completo.
- **`maps/mp/gametypes/global/_init.gsc`** — 1 línea agregada en `InitModules()`:
  `thread maps\mp\gametypes\_blood::init();`
- **Assets agregados/reemplazados** (sin cambios, solo copiados dentro del `.iwd`):
  - `fx/impacts/flesh_hit.efx` (reemplaza al original, versión más elaborada: 9.3KB vs
    5.4KB).
  - `fx/effects/gore/{splats,stains,stains_lg,stains2,stains2_lg,stains2_big}.efx`
    (nuevos).

#### Cvar

`scr_blood` (BOOL, default `1`) — togglable por rcon en caliente.

#### Comportamiento

- **`onPlayerDamaged`**: en cada impacto de bala/melee (`vPoint`/`vDir` definidos, y
  `sMeansOfDeath` es `MOD_PISTOL_BULLET`/`MOD_RIFLE_BULLET`/`MOD_MELEE`), dispara
  `flesh_hit` en el punto exacto de impacto, orientado según la dirección del disparo.
- **`onPlayerKilled`**: elige al azar uno de los 6 efectos de `gore/` y lo dispara en el
  piso, en la posición del cuerpo (`self.origin`, capturado **antes** de threadear, porque
  el jugador puede respawnear y moverse).

#### ⚠️ Limitación conocida: el "charco" no es un decal persistente

Los `.efx` de `gore/` son binarios muy chicos (240–290 bytes) → son ráfagas de partículas
de corta duración (1-2 segundos), **no decals persistentes**. En CoD2 las marcas que
"quedan pegadas" al piso/pared de verdad (ej. agujeros de bala) usan el sistema de
**decals** del motor, que es distinto al sistema de partículas `fx` y no tiene ningún
comando expuesto en GSC para dispararlo manualmente — solo se puede reproducir lo que el
propio `.efx` ya trae definido (no se puede "alargar" su duración interna desde script sin
editar el binario con una herramienta tipo IW Effects Editor).

**Workaround aplicado** (no es un decal real, pero disimula el corte): en vez de un solo
`playfx`, se re-dispara el mismo efecto en el mismo punto cada 1.5s durante 15s
(`bloodPoolPersist()`), corriendo en un thread de `level` (no de `self`) para que no
dependa de que el jugador siga vivo/conectado.

#### Otra limitación NO relacionada con el script: el cadáver desaparece

Se confirmó por búsqueda exhaustiva que **ningún `.gsc` de ZPAM borra o oculta el cuerpo**
de un jugador muerto. Dos explicaciones válidas, dependiendo del contexto de testing:

1. **Gametypes con respawn rápido (dm/tdm/etc.) o readyup/warmup**: el cadáver es la
   misma entidad del jugador — cuando ese jugador respawnea, la entidad se mueve al punto
   de spawn y el cuerpo "desaparece" de donde murió. Esto es así en cualquier mod de CoD,
   no se puede evitar por script.
2. **SD con ronda en curso, muchos bots muriendo rápido**: lo más probable es un límite
   nativo del motor (herencia de idTech3) de cantidad máxima de cadáveres simultáneos
   renderizados — al superarlo, el más viejo se recicla. Tampoco es controlable desde
   `.gsc`.

#### Código completo

```c
#include maps\mp\gametypes\global\_global;

/*
	Blood impact spray (on hit) + ground stain (on kill), using the "iw_blood" fx pack:
		fx/impacts/flesh_hit.efx
		fx/effects/gore/splats.efx, stains.efx, stains_lg.efx, stains2.efx, stains2_lg.efx, stains2_big.efx

	Nothing in ZPAM called loadfx()/playfx() for these assets before - the files just sat
	in the iwd unused. This module is what actually triggers them, the same way every
	maps\mp\mp_<map>_fx.gsc precaches and plays its own map effects.
*/

init()
{
	addEventListener("onCvarChanged", ::onCvarChanged);

	registerCvar("scr_blood", "BOOL", 1); // level.scr_blood

	level._effect["flesh_hit"]         = loadfx("fx/impacts/flesh_hit.efx");
	level._effect["blood_splats"]      = loadfx("fx/effects/gore/splats.efx");
	level._effect["blood_stains"]      = loadfx("fx/effects/gore/stains.efx");
	level._effect["blood_stains_lg"]   = loadfx("fx/effects/gore/stains_lg.efx");
	level._effect["blood_stains2"]     = loadfx("fx/effects/gore/stains2.efx");
	level._effect["blood_stains2_lg"]  = loadfx("fx/effects/gore/stains2_lg.efx");
	level._effect["blood_stains2_big"] = loadfx("fx/effects/gore/stains2_big.efx");

	addEventListener("onPlayerDamaged", ::onPlayerDamaged);
	addEventListener("onPlayerKilled", ::onPlayerKilled);
}

// This function is called when cvar changes value.
// Is also called when cvar is registered
// Return true if cvar was handled here, otherwise false
onCvarChanged(cvar, value, isRegisterTime)
{
	switch (cvar)
	{
		case "scr_blood":
			level.scr_blood = value;
			return true;
	}
	return false;
}

// self = victim (game engine convention for CodeCallback_PlayerDamage)
onPlayerDamaged(eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, sWeapon, vPoint, vDir, sHitLoc, timeOffset)
{
	if (level.scr_blood == 0)
		return;

	if (!isDefined(vPoint) || !isDefined(vDir))
		return;

	// Only actual weapon/melee hits on flesh (skip suicide/grenade-splash-only edge cases without a clean hit point)
	if (sMeansOfDeath != "MOD_PISTOL_BULLET" && sMeansOfDeath != "MOD_RIFLE_BULLET" && sMeansOfDeath != "MOD_MELEE")
		return;

	playfx(level._effect["flesh_hit"], vPoint, vDir);
}

// self = victim (game engine convention for CodeCallback_PlayerKilled)
onPlayerKilled(eInflictor, eAttacker, iDamage, sMeansOfDeath, sWeapon, vDir, sHitLoc, timeOffset, deathAnimDuration)
{
	if (level.scr_blood == 0)
		return;

	pool = pickBloodPool();
	origin = self.origin; // capture now - self (the player) will move away once respawned

	// The .efx itself is a short one-shot spray, not a persistent decal - re-trigger it
	// at the same spot for a while to fake a lasting pool on the ground.
	level thread bloodPoolPersist(pool, origin);
}

bloodPoolPersist(pool, origin)
{
	duration = 15; // seconds - tune this if it looks too short/long or costs too much perf
	interval = 1.5;

	for (elapsed = 0; elapsed < duration; elapsed += interval)
	{
		playfx(level._effect[pool], origin, (0, 0, 1));
		wait interval;
	}
}

pickBloodPool()
{
	pools = [];
	pools[pools.size] = "blood_splats";
	pools[pools.size] = "blood_stains";
	pools[pools.size] = "blood_stains_lg";
	pools[pools.size] = "blood_stains2";
	pools[pools.size] = "blood_stains2_lg";
	pools[pools.size] = "blood_stains2_big";

	return pools[randomint(pools.size)];
}
```

### 7.4. Estado de testing (confirmado en server real)

- ✅ Popup `+1` por kill normal — funcionando.
- ✅ Sangre al impactar (`flesh_hit`) — funcionando.
