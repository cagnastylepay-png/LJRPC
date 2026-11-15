# LJRPC

Client Luau de JSON-RPC 2.0 pour Roblox, avec relais WebSocket Render. Le relais accepte un client C# et une session Lua. Une connexion authentifiée transporte une requête à la fois.

```lua
local loader = assert(loadstring(game:HttpGet(
 "https://raw.githubusercontent.com/cagnastylepay-png/LJRPC/main/Loader.lua")))
local rpc = loader({
 Url = "wss://m4gix-ws.onrender.com/ljrpc/ws",
 Token = "<LJRPC_LUA_TOKEN>",
 AllowEval = true
})
```

Avec le dépôt privé, place `Loader.lua` et `LJRPC.lua` dans le dossier accessible à `readfile`, puis lance :

```lua
local loader = assert(loadstring(readfile("Loader.lua")))
local rpc = loader({
 Url = "wss://m4gix-ws.onrender.com/ljrpc/ws",
 LocalPath = "LJRPC.lua",
 Token = "<LJRPC_LUA_TOKEN>",
 AllowEval = true
})
```

`Source` permet aussi de passer le code du module en mémoire. `SourceUrl` permet d’utiliser une URL de distribution qui donne accès au fichier brut.

`AllowEval` autorise le client authentifié à exécuter du Luau dans la session. Active-le uniquement avec un client de confiance. Une fonction peut aussi être déclarée localement via `rpc.Register(name, fn)`. Un bloc envoyé à `Eval` reçoit le module RPC, puis les arguments de l’appel dans `...`. Le premier résultat est renvoyé. Les valeurs ordinaires doivent être sérialisables en JSON.

Une Instance renvoyée devient un objet JSON `{"$ref":"…" }`. Un argument de premier niveau portant ce champ est résolu avant l’appel. Les références restent valides dans la connexion qui les a créées et peuvent être libérées avec `Release`. Si une requête est en cours quand le client C# se déconnecte, le relais ferme aussi la connexion Lua. Le code Luau déjà lancé peut utiliser `rpc.ConnectionGuard()` pour vérifier que la connexion d’origine est encore ouverte.

Le relais utilise `LJRPC_LUA_TOKEN` et `LJRPC_CLIENT_TOKEN`, deux secrets distincts d’au moins 32 caractères. Les secrets passent dans la trame de connexion chiffrée par WSS.
