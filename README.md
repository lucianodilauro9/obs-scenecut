# SceneCut per OBS Studio

SceneCut scontorna la persona ripresa dalla webcam. Il filtro per Windows x64 include il modello MediaPipe in formato ONNX ed esegue l'inferenza sul PC tramite Windows ML. Per usare la versione 0.2.0 basta aggiungere un filtro alla fonte video.

**[Scarica SceneCut 0.2.0 per Windows](https://github.com/lucianodilauro9/obs-scenecut/releases/download/v0.2.0/SceneCut-Setup.exe)**

## Installazione

1. Esegui l'installer, scegli **Installa SceneCut** e poi **Copia percorso**. I file sono in `%LOCALAPPDATA%\SceneCut\0.2.0`.
2. In OBS apri **Strumenti  Script  +**. Incolla il percorso nel campo del nome file e aprilo.
3. In **Fonti**, apri i filtri della webcam. In **Filtri effetto  +** scegli **SceneCut**.
4. Posiziona l'immagine di sfondo sotto la webcam nell'elenco Fonti.

Se usi la 0.1.0, annota i tuoi valori e rimuovi il vecchio script da Strumenti  Script prima di caricare la nuova copia. Disabilita i precedenti filtri di rimozione o di chiave colore sulla webcam. Per installare manualmente estrai lo ZIP dei sorgenti e carica `scenecut.lua`, mantenendo la cartella `engine` e lo shader accanto allo script.

## Regolazione

- **Rifinitura bordi** parte da 12. Aumentala gradualmente se vedi un alone. Riducila se perdi dettagli dei capelli.
- **Stabilit� in movimento** parte da 35. Attenua piccole oscillazioni tra maschere consecutive e riduce la media quando la probabilit� cambia rapidamente. A zero la media temporale � disattivata.
- **Anteprima su fondo scuro** evidenzia i residui. Il fondo scuro fa parte dell'uscita video: disattivalo prima di registrare.

## Funzionamento e limiti

Il motore riceve fotogrammi RGB ridotti a 256 � 144 in memoria condivisa. Un processo separato calcola la probabilit� che ogni pixel appartenga alla persona. Il filtro conserva il fotogramma a piena risoluzione fino all'arrivo della sua maschera: cos� le mani in movimento e la loro sagoma restano sincronizzate. Il costo � una latenza aggiuntiva e la cadenza pu� diminuire sui PC pi� lenti. Lo shader usa i colori vicini per rifinire il bordo e restituisce un'immagine con trasparenza. Il modello lavora sulla CPU, il compositing usa la GPU. I fotogrammi rimangono in memoria locale.

Configurazione verificata: Windows 11 x64, OBS Studio 32.1.2, Direct3D 11, video SDR. Capelli fini, motion blur e oggetti tenuti in mano possono richiedere regolazioni. Se la fonte � vuota all'avvio, attendi il caricamento. In caso di errore apri le propriet� di SceneCut o il registro OBS. Il messaggio indica se manca il motore o se Windows ML ha restituito un errore.

Per disinstallare rimuovi il filtro, rimuovi lo script da OBS e cancella la cartella della versione dalla tua cartella SceneCut.

## Modello e compilazione

Il modello MediaPipe proviene dal pacchetto [OBS Background Removal 1.5.0](https://github.com/royshil/obs-backgroundremoval/releases/tag/1.5.0). Attribuzioni e licenza Apache 2.0 si trovano in `engine/portrait.onnx.license` e `engine/Apache-2.0.txt`. Il codice del filtro, dello shader, del processo Windows ML e dell'installer � incluso nel repository.

Per ricompilare il processo e l'installer usa Windows PowerShell e avvia `packaging/build.ps1` su Windows x64 con .NET Framework 4.x e i metadati Windows.AI. L'installer pu� anche estrarre il pacchetto in una cartella dedicata con `SceneCut-Setup.exe --extract CARTELLA`.
