# Link di sblocco delle skin di Halloween

Ogni link apre Stepbound e sblocca la skin su tutto il dispositivo, per tutti
gli slot presenti e futuri:

- Fantasma: `stepbound://unlock/7fcc3bdba2794318b697b64046adf9f8`
- Vampiro: `stepbound://unlock/29c874a68fca4ed78a18a536ac003510`
- Jack-o’-lantern: `stepbound://unlock/a6ead854a8d34080929282b76700d367`
- Zombi: `stepbound://unlock/141e8b6eb1d6474b96c28e9972f2d050`

I codici sono token casuali a 128 bit. I vecchi slug leggibili non sono più
accettati: il link va distribuito integralmente e senza modificarlo.

All’apertura l’app torna al menù principale e conferma lo sblocco. La skin
compare nel cambio abbigliamento solo dopo che la trama lo ha introdotto con
la tunica del Duomo; il guardaroba sul treno resta sempre un punto valido per
cambiarsi.

## Prova su dispositivo

Android, con l’app installata:

```shell
adb shell am start -W -a android.intent.action.VIEW \
  -d "stepbound://unlock/7fcc3bdba2794318b697b64046adf9f8"
```

iOS Simulator, con l’app installata:

```shell
xcrun simctl openurl booted \
  "stepbound://unlock/7fcc3bdba2794318b697b64046adf9f8"
```

Per provare le altre skin usare il relativo link completo riportato sopra.
