# SceneCut per OBS Studio

Prototipo 0.1.0 per Windows x64. Il filtro SceneCut si carica tramite il supporto Lua incluso in OBS. OBS Background Removal 1.5.0 elabora la webcam sul PC e fornisce la maschera di trasparenza. SceneCut rifinisce i pixel semitrasparenti, regola la stabilizzazione del motore e permette di vedere subito eventuali residui sullo sfondo.

[Scarica SceneCut per Windows (ZIP)](https://github.com/lucianodilauro9/obs-scenecut/archive/refs/heads/main.zip)

## Prova con OBS 32.1.2

1. Estrai l'intera cartella ZIP in una posizione stabile. Lascia insieme `scenecut.lua` e `scenecut.effect`.
2. Verifica che tra i filtri video di OBS sia disponibile **Background Removal** (in italiano può apparire come **Rimozione sfondo**). Se manca, installa il [motore 1.5.0 per Windows x64](https://github.com/royshil/obs-backgroundremoval/releases/tag/1.5.0) seguendo il file INSTALL.html e riavvia OBS.
3. Apri **Strumenti → Script**, premi **+** e seleziona `scenecut.lua`.
4. Apri **Fonti → webcam → Filtri**. Nei filtri effetto aggiungi il motore di rimozione e poi **SceneCut**, nell'ordine indicato dall'alto in basso. Se il motore è già presente, riusalo. Imposta la sua sfocatura a zero e lascia la soglia al valore iniziale di 0,5 per la prima prova.
5. Nella scena, disponi l'immagine di sfondo sotto la webcam. Seleziona SceneCut e attiva **Anteprima su fondo scuro**. Muovi una mano e gira la testa mentre osservi i capelli. Disattiva l'anteprima prima della registrazione.

## Controlli

- **Rifinitura bordi** attenua l'alone sui contorni. Parti da zero e sali gradualmente. Un valore elevato può cancellare dettagli sottili.
- **Stabilità in movimento** regola il peso dei fotogrammi precedenti nel motore. Il valore zero disattiva la media temporale. Riduci il valore se le mani lasciano una scia. Durante l'uso è SceneCut a controllare il parametro temporale del motore.
- **Anteprima su fondo scuro** sostituisce la trasparenza con un colore scuro nella stessa uscita video di OBS. Il cambiamento compare anche in diretta e in registrazione.

Se vedi ancora un rettangolo opaco, controlla l'ordine dei due filtri, il loro stato attivo e la sfocatura del motore. I filtri che agiscono sulla stessa fonte vengono condivisi tra le scene che la usano.

Il prototipo richiede il motore esterno. L'installer unico e il collaudo con webcam fisica sono previsti per la beta. Per rimuovere SceneCut elimina il suo filtro dalla webcam e poi lo script da Strumenti → Script. Puoi ripristinare la stabilizzazione predefinita del motore al valore 0,85.
