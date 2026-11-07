/**
 * GOOGLE APPS SCRIPT - SPELEO CLUB ROMA
 * Webhook per Sincronizzazione Magazzino Speleo (Offline-First Flutter App)
 * 
 * ISTRUZIONI:
 * 1. Apri il tuo foglio Google Sheets su Google Drive.
 * 2. Clicca su "Estensioni" -> "Apps Script".
 * 3. Incolla questo codice nel file Code.gs (sostituendo il contenuto esistente).
 * 4. Clicca su "Salva" (icona dischetto).
 * 5. Seleziona dal menu a tendina delle funzioni "correggiEFormattaTuttiIFogli" e clicca su "Esegui".
 *    -> Questo allineerà automaticamente TUTTI i fogli (Prelievi, Dettagli, Catalogo)
 *       senza farti perdere neanche un dato!
 * 6. Clicca su "Distribuisci" -> "Gestisci distribuzioni" -> modifica la distribuzione attiva
 *    (oppure "Nuova distribuzione"):
 *    - Tipo: "Applicazione web" (Web App).
 *    - Esegui come: "Io" (Me).
 *    - Chi ha accesso: "Chiunque" (Anyone).
 * 7. Copia l'URL dell'applicazione web (termina con /exec) e inseriscilo nell'app Speleo Magazzino.
 */

// Nomi dei fogli all'interno del documento
const SHEET_PRELIEVI = "Prelievi";
const SHEET_DETTAGLI = "Dettagli";
const SHEET_CATALOGO = "Catalogo";

/**
 * Crea il menu rapido in Google Sheets ogni volta che il documento viene aperto
 */
function onOpen() {
  try {
    SpreadsheetApp.getUi()
      .createMenu("Speleo Magazzino")
      .addItem("⚡ Allinea e Formatta Fogli (Automatico)", "correggiEFormattaTuttiIFogli")
      .addToUi();
  } catch (e) {
    // Non disponibile in contesti trigger headless
  }
}

/**
 * Gestione richieste GET (Health check / Ping / Scaricamento Catalogo / Scaricamento Prelievi)
 */
function doGet(e) {
  try {
    const action = (e && e.parameter && e.parameter.action) ? e.parameter.action : "ping";
    const ss = SpreadsheetApp.getActiveSpreadsheet();

    if (action === "ping") {
      return jsonResponse({
        status: "ok",
        message: "Connessione a Google Sheets attiva!",
        spreadsheet_name: ss.getName(),
        timestamp: new Date().toISOString()
      });
    }

    if (action === "get_catalogo") {
      const sheet = ss.getSheetByName(SHEET_CATALOGO);
      if (!sheet) {
        return jsonResponse({ status: "success", catalogo: [] });
      }
      const data = sheet.getDataRange().getValues();
      if (data.length <= 1) {
        return jsonResponse({ status: "success", catalogo: [] });
      }

      const catalogo = [];
      for (let i = 1; i < data.length; i++) {
        const row = data[i];
        if (row[0] && row[0].toString().trim() !== "") {
          catalogo.push({
            id_materiale: row[0].toString().trim(),
            categoria: (row[1] || "").toString().trim(),
            nome_oggetto: (row[2] || "").toString().trim()
          });
        }
      }
      return jsonResponse({ status: "success", catalogo: catalogo });
    }

    if (action === "get_prelievi") {
      const sheetP = ss.getSheetByName(SHEET_PRELIEVI);
      const sheetD = ss.getSheetByName(SHEET_DETTAGLI);
      const sheetC = ss.getSheetByName(SHEET_CATALOGO);

      // Carica catalogo per risolvere nomi o categorie mancanti nei dettagli
      const catalogoMap = {};
      if (sheetC) {
        const dataC = sheetC.getDataRange().getValues();
        for (let i = 1; i < dataC.length; i++) {
          const rowC = dataC[i];
          if (rowC[0]) {
            catalogoMap[rowC[0].toString().trim()] = {
              categoria: (rowC[1] || "").toString().trim(),
              nome: (rowC[2] || "").toString().trim()
            };
          }
        }
      }

      const prelievi = [];
      const dettagli = [];

      // 1. Leggi Foglio Prelievi
      if (sheetP) {
        const dataP = sheetP.getDataRange().getValues();
        if (dataP.length > 1) {
          const headerP = dataP[0].map(h => h.toString().toLowerCase().trim());
          
          const colId = findColIndex(headerP, ["id", "id_prelievo", "id prelievo"], -1);
          const colData = findColIndex(headerP, ["data", "data prelievo", "data di prelievo"], -1);
          const colLuogo = findColIndex(headerP, ["luogo", "luogo / grotta", "luogo/grotta"], -1);
          const colResp = findColIndex(headerP, ["responsabile"], -1);
          const colStato = findColIndex(headerP, ["stato"], -1);
          const colRiconsegna = findColIndex(headerP, ["data di riconsegna", "data riconsegna", "data rientro", "data_rientro", "riconsegna"], -1);
          const colOperatore = findColIndex(headerP, ["operatore", "operatore rientro", "operatore_rientro"], -1);
          const colEmailMag = findColIndex(headerP, ["email magazzinieri", "email_magazzinieri", "cc"], -1);
          const colParere = findColIndex(headerP, ["parere", "note / parere", "note/parere", "note"], -1);

          for (let i = 1; i < dataP.length; i++) {
            const row = dataP[i];
            const id = (colId >= 0 && row[colId]) ? row[colId].toString().trim() : "";
            if (!id) continue;

            const riconsegnaVal = (colRiconsegna >= 0 && row[colRiconsegna]) ? row[colRiconsegna] : null;
            let stato = (colStato >= 0 && row[colStato]) ? row[colStato].toString().trim() : "";
            if (!stato) {
              if (riconsegnaVal && riconsegnaVal.toString().trim() !== "") {
                stato = "Materiale rientrato";
              } else {
                stato = "In attesa materiale";
              }
            }

            let dataIso = "";
            const rawData = (colData >= 0) ? row[colData] : null;
            if (rawData instanceof Date) {
              dataIso = rawData.toISOString();
            } else if (rawData) {
              dataIso = rawData.toString().trim();
            } else {
              dataIso = new Date().toISOString();
            }

            let dataRientroIso = "";
            if (riconsegnaVal instanceof Date) {
              dataRientroIso = riconsegnaVal.toISOString();
            } else if (riconsegnaVal) {
              dataRientroIso = riconsegnaVal.toString().trim();
            }

            prelievi.push({
              id: id,
              data_prelievo: dataIso,
              luogo_grotta: (colLuogo >= 0 && row[colLuogo]) ? row[colLuogo].toString().trim() : "",
              responsabile: (colResp >= 0 && row[colResp]) ? row[colResp].toString().trim() : "",
              stato: stato,
              parere: (colParere >= 0 && row[colParere]) ? row[colParere].toString().trim() : "",
              data_rientro: dataRientroIso,
              operatore_rientro: (colOperatore >= 0 && row[colOperatore]) ? row[colOperatore].toString().trim() : "",
              email_magazzinieri: (colEmailMag >= 0 && row[colEmailMag]) ? row[colEmailMag].toString().trim() : ""
            });
          }
        }
      }

      // 2. Leggi Foglio Dettagli
      if (sheetD) {
        const dataD = sheetD.getDataRange().getValues();
        if (dataD.length > 1) {
          const headerD = dataD[0].map(h => h.toString().toLowerCase().trim());
          
          const colIdDet = findColIndex(headerD, ["id dettaglio", "id_dettaglio", "id"], -1);
          const colPrelievoId = findColIndex(headerD, ["id prelievo", "id_prelievo"], -1);
          const colMatId = findColIndex(headerD, ["id materiale", "id_materiale"], -1);
          const colCat = findColIndex(headerD, ["categoria"], -1);
          const colNome = findColIndex(headerD, ["nome materiale", "nome_oggetto", "nome oggetto", "nome"], -1);
          const colQta = findColIndex(headerD, ["q.tà prelevata", "quantità prelevata", "quantita prelevata", "quantità", "quantita", "qta"], -1);
          const colSpunta = findColIndex(headerD, ["spunta rientro", "spunta_rientro", "spunta"], -1);
          const colQtaTornata = findColIndex(headerD, ["q.tà tornata", "quantità tornata", "quantita tornata", "qta_tornata"], -1);
          const colNote = findColIndex(headerD, ["note rientro", "note_rientro", "note"], -1);

          for (let i = 1; i < dataD.length; i++) {
            const row = dataD[i];
            const idDet = (colIdDet >= 0 && row[colIdDet]) ? row[colIdDet].toString().trim() : "";
            const prelievoId = (colPrelievoId >= 0 && row[colPrelievoId]) ? row[colPrelievoId].toString().trim() : "";
            const matId = (colMatId >= 0 && row[colMatId]) ? row[colMatId].toString().trim() : "";
            if (!idDet || !prelievoId || !matId) continue;

            let cat = (colCat >= 0 && row[colCat]) ? row[colCat].toString().trim() : "";
            let nome = (colNome >= 0 && row[colNome]) ? row[colNome].toString().trim() : "";
            if ((!cat || !nome) && catalogoMap[matId]) {
              if (!cat) cat = catalogoMap[matId].categoria;
              if (!nome) nome = catalogoMap[matId].nome;
            }

            const qta = (colQta >= 0 && row[colQta] !== "") ? (parseInt(row[colQta], 10) || 1) : 1;
            const spuntaRaw = (colSpunta >= 0 && row[colSpunta]) ? row[colSpunta].toString().trim().toUpperCase() : "";
            const isSpunta = (spuntaRaw === "SI" || spuntaRaw === "1" || spuntaRaw === "TRUE");
            const qtaTornataRaw = (colQtaTornata >= 0 && row[colQtaTornata] !== "") ? parseInt(row[colQtaTornata], 10) : null;

            dettagli.push({
              id_dettaglio: idDet,
              prelievo_id: prelievoId,
              materiale_id: matId,
              categoria: cat,
              nome_materiale: nome,
              quantita_prelevata: qta,
              spunta_rientro: isSpunta ? 1 : 0,
              qta_tornata: isNaN(qtaTornataRaw) ? null : qtaTornataRaw,
              note_rientro: (colNote >= 0 && row[colNote]) ? row[colNote].toString().trim() : ""
            });
          }
        }
      }

      return jsonResponse({
        status: "success",
        prelievi: prelievi,
        dettagli_prelievo: dettagli,
        timestamp: new Date().toISOString()
      });
    }

    return jsonResponse({ status: "error", message: "Azione sconosciuta: " + action }, 400);
  } catch (err) {
    return jsonResponse({ status: "error", message: err.toString() }, 500);
  }
}

/**
 * Gestione richieste POST (Sincronizzazione dati da SQLite a Google Sheets)
 */
function doPost(e) {
  const lock = LockService.getScriptLock();
  try {
    lock.waitLock(30000);
  } catch (e) {
    return jsonResponse({ status: "error", message: "Foglio occupato da un'altra sincronizzazione, riprova." }, 503);
  }

  try {
    if (!e || !e.postData || !e.postData.contents) {
      return jsonResponse({ status: "error", message: "Nessun dato inviato nel corpo della richiesta." }, 400);
    }

    const payload = JSON.parse(e.postData.contents);
    const ss = SpreadsheetApp.getActiveSpreadsheet();
    
    setupSheetsIfNeeded(ss);

    let prelieviAggiornati = 0;
    let dettagliAggiornati = 0;

    // 1. Sincronizza Testate (Prelievi) ed invia eventuali notifiche email di rientro
    if (payload.prelievi && Array.isArray(payload.prelievi)) {
      const sheetP = ss.getSheetByName(SHEET_PRELIEVI);
      prelieviAggiornati = syncPrelievi(sheetP, payload.prelievi, payload.dettagli_prelievo || []);
    }

    // 2. Sincronizza Righe (Dettagli)
    if (payload.dettagli_prelievo && Array.isArray(payload.dettagli_prelievo)) {
      const sheetD = ss.getSheetByName(SHEET_DETTAGLI);
      dettagliAggiornati = syncDettagli(sheetD, payload.dettagli_prelievo);
    }

    return jsonResponse({
      status: "success",
      message: "Sincronizzazione completata con successo!",
      prelievi_synced: prelieviAggiornati,
      dettagli_synced: dettagliAggiornati,
      timestamp: new Date().toISOString()
    });

  } catch (err) {
    return jsonResponse({ status: "error", message: err.toString() }, 500);
  } finally {
    lock.releaseLock();
  }
}

/**
 * Inserisce o aggiorna le righe di Prelievi (Upsert basato su id prelievo)
 * Utilizza mappatura dinamica delle colonne: nessuna colonna viene sovrascritta.
 */
function syncPrelievi(sheet, prelievi, tuttiDettagli) {
  const nowStr = Utilities.formatDate(new Date(), Session.getScriptTimeZone(), "yyyy-MM-dd HH:mm:ss");
  const data = sheet.getDataRange().getValues();
  
  let headers = [];
  if (data.length > 0) {
    headers = data[0].map(function(h) { return h.toString().toLowerCase().trim(); });
  }

  function ensureColumn(name, possibleMatches) {
    let idx = findColIndex(headers, possibleMatches, -1);
    if (idx === -1) {
      idx = headers.length;
      sheet.getRange(1, idx + 1).setValue(name);
      headers.push(name.toLowerCase().trim());
      styleHeader(sheet, headers.length);
    }
    return idx;
  }

  const colId = ensureColumn("ID Prelievo", ["id", "id_prelievo", "id prelievo"]);
  const colData = ensureColumn("Data Prelievo", ["data", "data prelievo", "data di prelievo"]);
  const colLuogo = ensureColumn("Luogo / Grotta", ["luogo", "luogo / grotta", "luogo/grotta"]);
  const colResp = ensureColumn("Responsabile", ["responsabile"]);
  const colStato = ensureColumn("Stato", ["stato"]);
  const colRiconsegna = ensureColumn("Data Riconsegna", ["data di riconsegna", "data riconsegna", "data rientro", "data_rientro", "riconsegna"]);
  const colOperatore = ensureColumn("Operatore", ["operatore", "operatore rientro", "operatore_rientro"]);
  const colEmailMag = ensureColumn("Email Magazzinieri", ["email magazzinieri", "email_magazzinieri", "cc"]);
  const colParere = ensureColumn("Note / Parere", ["parere", "note / parere", "note/parere", "note"]);
  const colNotifica = ensureColumn("Notifica Inviata", ["notifica inviata", "notifica", "email_inviata"]);
  const colAggiornamento = ensureColumn("Ultimo Aggiornamento", ["ultimo aggiornamento", "aggiornamento"]);

  // Mappa id -> riga (1-indexed)
  const idToRowMap = {};
  for (let r = 1; r < data.length; r++) {
    const id = data[r][colId];
    if (id) {
      idToRowMap[id.toString().trim()] = r + 1;
    }
  }

  let count = 0;
  for (let i = 0; i < prelievi.length; i++) {
    const p = prelievi[i];
    const targetRow = idToRowMap[p.id];

    let notificaGiaInviata = false;
    if (targetRow && data[targetRow - 1] && colNotifica < data[targetRow - 1].length) {
      const valNotifica = data[targetRow - 1][colNotifica];
      if (valNotifica && valNotifica.toString().trim().toUpperCase() === "SI") {
        notificaGiaInviata = true;
      }
    }

    let inviataOra = false;
    if (!notificaGiaInviata && p.operatore_rientro && (p.stato === "Materiale rientrato" || p.stato === "Materiale mancante" || p.data_rientro)) {
      const prelievoDettagli = (tuttiDettagli || []).filter(function(d) {
        return d.prelievo_id === p.id;
      });
      inviataOra = sendRientroNotificationEmail(p, prelievoDettagli);
    }

    const rowLength = headers.length;
    const rowValues = new Array(rowLength).fill("");

    rowValues[colId] = p.id;
    rowValues[colData] = p.data_prelievo;
    rowValues[colLuogo] = p.luogo_grotta;
    rowValues[colResp] = p.responsabile;
    rowValues[colStato] = p.stato;
    rowValues[colRiconsegna] = p.data_rientro || "";
    rowValues[colOperatore] = p.operatore_rientro || "";
    rowValues[colEmailMag] = p.email_magazzinieri || "";
    rowValues[colParere] = p.parere || "";
    rowValues[colNotifica] = (notificaGiaInviata || inviataOra) ? "SI" : "NO";
    rowValues[colAggiornamento] = nowStr;

    if (targetRow) {
      sheet.getRange(targetRow, 1, 1, rowValues.length).setValues([rowValues]);
    } else {
      sheet.appendRow(rowValues);
      idToRowMap[p.id] = sheet.getLastRow();
    }
    count++;
  }
  return count;
}

/**
 * Inserisce o aggiorna le righe di Dettagli (Upsert basato su id_dettaglio)
 * Utilizza mappatura dinamica delle colonne per adattarsi a qualsiasi ordine.
 */
function syncDettagli(sheet, dettagli) {
  const nowStr = Utilities.formatDate(new Date(), Session.getScriptTimeZone(), "yyyy-MM-dd HH:mm:ss");
  const data = sheet.getDataRange().getValues();

  let headers = [];
  if (data.length > 0) {
    headers = data[0].map(function(h) { return h.toString().toLowerCase().trim(); });
  }

  function ensureColumn(name, possibleMatches) {
    let idx = findColIndex(headers, possibleMatches, -1);
    if (idx === -1) {
      idx = headers.length;
      sheet.getRange(1, idx + 1).setValue(name);
      headers.push(name.toLowerCase().trim());
      styleHeader(sheet, headers.length);
    }
    return idx;
  }

  const colId = ensureColumn("ID Dettaglio", ["id dettaglio", "id_dettaglio", "id"]);
  const colPrelievoId = ensureColumn("ID Prelievo", ["id prelievo", "id_prelievo"]);
  const colMatId = ensureColumn("ID Materiale", ["id materiale", "id_materiale"]);
  const colCat = ensureColumn("Categoria", ["categoria"]);
  const colNome = ensureColumn("Nome Materiale", ["nome materiale", "nome_oggetto", "nome oggetto", "nome"]);
  const colQta = ensureColumn("Q.tà Prelevata", ["q.tà prelevata", "quantità prelevata", "quantita prelevata", "quantità", "quantita", "qta"]);
  const colSpunta = ensureColumn("Spunta Rientro", ["spunta rientro", "spunta_rientro", "spunta"]);
  const colQtaTornata = ensureColumn("Q.tà Tornata", ["q.tà tornata", "quantità tornata", "quantita tornata", "qta_tornata"]);
  const colNote = ensureColumn("Note Rientro", ["note rientro", "note_rientro", "note"]);
  const colAgg = ensureColumn("Ultimo Aggiornamento", ["ultimo aggiornamento", "aggiornamento"]);

  // Mappa id_dettaglio -> riga
  const idToRowMap = {};
  for (let r = 1; r < data.length; r++) {
    const id = data[r][colId];
    if (id) {
      idToRowMap[id.toString().trim()] = r + 1;
    }
  }

  let count = 0;
  for (let i = 0; i < dettagli.length; i++) {
    const d = dettagli[i];
    const spuntaStr = (d.spunta_rientro === 1 || d.spunta_rientro === true) ? "SI" : "NO";
    const rowLength = headers.length;
    const rowValues = new Array(rowLength).fill("");

    rowValues[colId] = d.id_dettaglio;
    rowValues[colPrelievoId] = d.prelievo_id;
    rowValues[colMatId] = d.materiale_id;
    rowValues[colCat] = d.categoria || "";
    rowValues[colNome] = d.nome_materiale || "";
    rowValues[colQta] = d.quantita_prelevata;
    rowValues[colSpunta] = spuntaStr;
    rowValues[colQtaTornata] = (d.qta_tornata !== null && d.qta_tornata !== undefined) ? d.qta_tornata : "";
    rowValues[colNote] = d.note_rientro || "";
    rowValues[colAgg] = nowStr;

    if (idToRowMap[d.id_dettaglio]) {
      const targetRow = idToRowMap[d.id_dettaglio];
      sheet.getRange(targetRow, 1, 1, rowValues.length).setValues([rowValues]);
    } else {
      sheet.appendRow(rowValues);
      idToRowMap[d.id_dettaglio] = sheet.getLastRow();
    }
    count++;
  }
  return count;
}

/**
 * Invia email di notifica rientro all'operatore e in copia conoscenza ai magazzinieri
 */
function sendRientroNotificationEmail(prelievo, dettagli) {
  try {
    const toEmail = (prelievo.operatore_rientro || "").trim();
    if (!toEmail || toEmail.indexOf("@") === -1) {
      Logger.log("Email operatore non valida o assente: " + toEmail);
      return false;
    }

    const ccEmail = (prelievo.email_magazzinieri || "magazzino@speleoclubroma.org").trim();
    const isTuttoOk = prelievo.stato === "Materiale rientrato";
    const subjectPrefix = isTuttoOk ? "[SCR Magazzino] Rientro Materiale Completo" : "[SCR Magazzino] ATTENZIONE: Rientro con Materiale Mancante";
    const subject = subjectPrefix + ": " + prelievo.luogo_grotta + " (" + prelievo.responsabile + ")";

    let body = "SCHEDA RICONSEGNA MATERIALI - SPELEO CLUB ROMA\n";
    body += "====================================================\n\n";
    body += "Luogo / Grotta: " + prelievo.luogo_grotta + "\n";
    body += "Responsabile Uscita: " + prelievo.responsabile + "\n";
    body += "Data Prelievo: " + prelievo.data_prelievo + "\n";
    body += "Data e Ora Chiusura Spunta: " + (prelievo.data_rientro || new Date().toISOString()) + "\n";
    body += "Operatore Riconsegna: " + toEmail + "\n";
    body += "Stato Finale Scheda: " + prelievo.stato + "\n";

    if (prelievo.parere && prelievo.parere.trim() !== "") {
      body += "Note / Parere: " + prelievo.parere + "\n";
    }

    body += "\n--- DETTAGLIO MATERIALI ---\n";
    const ammanchi = [];
    if (dettagli && dettagli.length > 0) {
      for (let i = 0; i < dettagli.length; i++) {
        const d = dettagli[i];
        const nome = d.nome_materiale || d.materiale_id;
        const qPrelevata = parseInt(d.quantita_prelevata, 10) || 0;
        let qTornata = 0;
        if (d.qta_tornata !== null && d.qta_tornata !== undefined && d.qta_tornata !== "") {
          qTornata = parseInt(d.qta_tornata, 10);
        } else if (d.spunta_rientro === 1 || d.spunta_rientro === true || d.spunta_rientro === "SI") {
          qTornata = qPrelevata;
        }

        const note = d.note_rientro ? (" [Note: " + d.note_rientro + "]") : "";
        body += "• " + nome + " (" + (d.categoria || "") + "): " + qTornata + " / " + qPrelevata + " pz rientrati" + note + "\n";

        if (qTornata < qPrelevata) {
          ammanchi.push(nome + ": mancanti " + (qPrelevata - qTornata) + " pz" + (d.note_rientro ? " (" + d.note_rientro + ")" : ""));
        }
      }
    }

    if (ammanchi.length > 0) {
      body += "\n⚠️ ATTENZIONE - RILEVATI I SEGUENTI AMMANCHI / ANOMALIE:\n";
      for (let j = 0; j < ammanchi.length; j++) {
        body += "! " + ammanchi[j] + "\n";
      }
    } else {
      body += "\n✅ Tutti i materiali prelevati sono stati riconsegnati integri in magazzino.\n";
    }

    body += "\n----------------------------------------------------\n";
    body += "Messaggio generato automaticamente dal sistema Magazzino SCR.\n";

    const mailOptions = {
      to: toEmail,
      subject: subject,
      body: body
    };
    if (ccEmail && ccEmail.indexOf("@") !== -1 && ccEmail.toLowerCase() !== toEmail.toLowerCase()) {
      mailOptions.cc = ccEmail;
    }

    MailApp.sendEmail(mailOptions);
    Logger.log("Email inviata con successo a: " + toEmail + " CC: " + ccEmail);
    return true;
  } catch (err) {
    Logger.log("Errore durante l'invio dell'email: " + err);
    return false;
  }
}

/**
 * Assicura che i 3 fogli esistano con le rispettive intestazioni standard
 */
function setupSheetsIfNeeded(ss) {
  let sheetC = ss.getSheetByName(SHEET_CATALOGO);
  if (!sheetC) {
    sheetC = ss.insertSheet(SHEET_CATALOGO);
    sheetC.getRange(1, 1, 1, 3).setValues([["ID Materiale", "Categoria", "Nome Oggetto"]]);
    styleHeader(sheetC, 3);
    popolaCatalogoUfficiale(sheetC);
  }

  let sheetP = ss.getSheetByName(SHEET_PRELIEVI);
  if (!sheetP) {
    sheetP = ss.insertSheet(SHEET_PRELIEVI);
    const headersP = [
      ["ID Prelievo", "Data Prelievo", "Luogo / Grotta", "Responsabile", "Stato", "Data Riconsegna", "Operatore", "Email Magazzinieri", "Note / Parere", "Notifica Inviata", "Ultimo Aggiornamento"]
    ];
    sheetP.getRange(1, 1, 1, headersP[0].length).setValues(headersP);
    styleHeader(sheetP, headersP[0].length);
  }

  let sheetD = ss.getSheetByName(SHEET_DETTAGLI);
  if (!sheetD) {
    sheetD = ss.insertSheet(SHEET_DETTAGLI);
    const headersD = [
      ["ID Dettaglio", "ID Prelievo", "ID Materiale", "Categoria", "Nome Materiale", "Q.tà Prelevata", "Spunta Rientro", "Q.tà Tornata", "Note Rientro", "Ultimo Aggiornamento"]
    ];
    sheetD.getRange(1, 1, 1, headersD[0].length).setValues(headersD);
    styleHeader(sheetD, headersD[0].length);
  }
}

/**
 * Funzione richiamabile manualmente da Apps Script:
 * Esegue l'allineamento e formattazione completa e automatica di tutti i fogli.
 */
function setupInitialSheets() {
  correggiEFormattaTuttiIFogli();
}

/**
 * Allinea, riorganizza e formatta tutti i fogli (Prelievi, Dettagli, Catalogo)
 * mantenendo tutti i dati esistenti e inserendo automaticamente le colonne e le intestazioni corrette.
 */
function correggiEFormattaTuttiIFogli() {
  const ss = SpreadsheetApp.getActiveSpreadsheet();

  // 1. Assicura e formatta Foglio Catalogo
  let sheetC = ss.getSheetByName(SHEET_CATALOGO);
  if (!sheetC) {
    sheetC = ss.insertSheet(SHEET_CATALOGO);
  }
  const headersC = [["ID Materiale", "Categoria", "Nome Oggetto"]];
  const dataC = sheetC.getDataRange().getValues();
  if (dataC.length === 0 || (dataC.length === 1 && !dataC[0][0])) {
    sheetC.getRange(1, 1, 1, headersC[0].length).setValues(headersC);
    popolaCatalogoUfficiale(sheetC);
  } else {
    sheetC.getRange(1, 1, 1, headersC[0].length).setValues(headersC);
  }
  styleHeader(sheetC, headersC[0].length);

  // Mappa di consultazione Catalogo per arricchire i Dettagli con nome e categoria
  const catalogoMap = {};
  const currentDataC = sheetC.getDataRange().getValues();
  for (let i = 1; i < currentDataC.length; i++) {
    const rowC = currentDataC[i];
    if (rowC[0]) {
      catalogoMap[rowC[0].toString().trim()] = {
        categoria: (rowC[1] || "").toString().trim(),
        nome: (rowC[2] || "").toString().trim()
      };
    }
  }

  // 2. Allinea e Riorganizza Foglio Prelievi
  let sheetP = ss.getSheetByName(SHEET_PRELIEVI);
  if (!sheetP) {
    sheetP = ss.insertSheet(SHEET_PRELIEVI);
  }
  const officialHeadersP = [
    "ID Prelievo",
    "Data Prelievo",
    "Luogo / Grotta",
    "Responsabile",
    "Stato",
    "Data Riconsegna",
    "Operatore",
    "Email Magazzinieri",
    "Note / Parere",
    "Notifica Inviata",
    "Ultimo Aggiornamento"
  ];

  const dataP = sheetP.getDataRange().getValues();
  const rowsP = [];

  if (dataP.length > 1) {
    const oldHeadersP = dataP[0].map(function(h) { return h.toString().toLowerCase().trim(); });
    const colId = findColIndex(oldHeadersP, ["id", "id_prelievo", "id prelievo"], -1);
    const colData = findColIndex(oldHeadersP, ["data", "data prelievo", "data di prelievo"], -1);
    const colLuogo = findColIndex(oldHeadersP, ["luogo", "luogo / grotta", "luogo/grotta"], -1);
    const colResp = findColIndex(oldHeadersP, ["responsabile"], -1);
    const colStato = findColIndex(oldHeadersP, ["stato"], -1);
    const colRiconsegna = findColIndex(oldHeadersP, ["data di riconsegna", "data riconsegna", "data rientro", "data_rientro", "riconsegna"], -1);
    const colOperatore = findColIndex(oldHeadersP, ["operatore", "operatore rientro", "operatore_rientro"], -1);
    const colEmailMag = findColIndex(oldHeadersP, ["email magazzinieri", "email_magazzinieri", "cc"], -1);
    const colParere = findColIndex(oldHeadersP, ["parere", "note / parere", "note/parere", "note"], -1);
    const colNotifica = findColIndex(oldHeadersP, ["notifica inviata", "notifica", "email_inviata"], -1);
    const colAgg = findColIndex(oldHeadersP, ["ultimo aggiornamento", "aggiornamento"], -1);

    for (let r = 1; r < dataP.length; r++) {
      const row = dataP[r];
      const id = (colId >= 0 && row[colId]) ? row[colId].toString().trim() : "";
      if (!id) continue;

      const rawRiconsegna = (colRiconsegna >= 0 && row[colRiconsegna]) ? row[colRiconsegna] : "";
      let stato = (colStato >= 0 && row[colStato]) ? row[colStato].toString().trim() : "";
      if (!stato) {
        stato = (rawRiconsegna && rawRiconsegna.toString().trim() !== "") ? "Materiale rientrato" : "In attesa materiale";
      }

      let dataIso = "";
      const rawData = (colData >= 0) ? row[colData] : null;
      if (rawData instanceof Date) {
        dataIso = rawData.toISOString();
      } else if (rawData) {
        dataIso = rawData.toString().trim();
      } else {
        dataIso = new Date().toISOString();
      }

      let dataRientroIso = "";
      if (rawRiconsegna instanceof Date) {
        dataRientroIso = rawRiconsegna.toISOString();
      } else if (rawRiconsegna) {
        dataRientroIso = rawRiconsegna.toString().trim();
      }

      rowsP.push([
        id,
        dataIso,
        (colLuogo >= 0 && row[colLuogo]) ? row[colLuogo].toString().trim() : "",
        (colResp >= 0 && row[colResp]) ? row[colResp].toString().trim() : "",
        stato,
        dataRientroIso,
        (colOperatore >= 0 && row[colOperatore]) ? row[colOperatore].toString().trim() : "",
        (colEmailMag >= 0 && row[colEmailMag]) ? row[colEmailMag].toString().trim() : "",
        (colParere >= 0 && row[colParere]) ? row[colParere].toString().trim() : "",
        (colNotifica >= 0 && row[colNotifica]) ? row[colNotifica].toString().trim() : "NO",
        (colAgg >= 0 && row[colAgg]) ? row[colAgg].toString().trim() : Utilities.formatDate(new Date(), Session.getScriptTimeZone(), "yyyy-MM-dd HH:mm:ss")
      ]);
    }
  }

  // Riscrittura pulita Foglio Prelievi
  sheetP.clear();
  sheetP.getRange(1, 1, 1, officialHeadersP.length).setValues([officialHeadersP]);
  if (rowsP.length > 0) {
    sheetP.getRange(2, 1, rowsP.length, officialHeadersP.length).setValues(rowsP);
  }
  styleHeader(sheetP, officialHeadersP.length);

  // 3. Allinea e Riorganizza Foglio Dettagli
  let sheetD = ss.getSheetByName(SHEET_DETTAGLI);
  if (!sheetD) {
    sheetD = ss.insertSheet(SHEET_DETTAGLI);
  }
  const officialHeadersD = [
    "ID Dettaglio",
    "ID Prelievo",
    "ID Materiale",
    "Categoria",
    "Nome Materiale",
    "Q.tà Prelevata",
    "Spunta Rientro",
    "Q.tà Tornata",
    "Note Rientro",
    "Ultimo Aggiornamento"
  ];

  const dataD = sheetD.getDataRange().getValues();
  const rowsD = [];

  if (dataD.length > 1) {
    const oldHeadersD = dataD[0].map(function(h) { return h.toString().toLowerCase().trim(); });
    const colIdDet = findColIndex(oldHeadersD, ["id dettaglio", "id_dettaglio", "id"], -1);
    const colPrelievoId = findColIndex(oldHeadersD, ["id prelievo", "id_prelievo"], -1);
    const colMatId = findColIndex(oldHeadersD, ["id materiale", "id_materiale"], -1);
    const colCat = findColIndex(oldHeadersD, ["categoria"], -1);
    const colNome = findColIndex(oldHeadersD, ["nome materiale", "nome_oggetto", "nome oggetto", "nome"], -1);
    const colQta = findColIndex(oldHeadersD, ["q.tà prelevata", "quantità prelevata", "quantita prelevata", "quantità", "quantita", "qta"], -1);
    const colSpunta = findColIndex(oldHeadersD, ["spunta rientro", "spunta_rientro", "spunta"], -1);
    const colQtaTornata = findColIndex(oldHeadersD, ["q.tà tornata", "quantità tornata", "quantita tornata", "qta_tornata"], -1);
    const colNote = findColIndex(oldHeadersD, ["note rientro", "note_rientro", "note"], -1);
    const colAgg = findColIndex(oldHeadersD, ["ultimo aggiornamento", "aggiornamento"], -1);

    for (let r = 1; r < dataD.length; r++) {
      const row = dataD[r];
      const idDet = (colIdDet >= 0 && row[colIdDet]) ? row[colIdDet].toString().trim() : "";
      const prelievoId = (colPrelievoId >= 0 && row[colPrelievoId]) ? row[colPrelievoId].toString().trim() : "";
      const matId = (colMatId >= 0 && row[colMatId]) ? row[colMatId].toString().trim() : "";
      if (!idDet || !prelievoId || !matId) continue;

      let cat = (colCat >= 0 && row[colCat]) ? row[colCat].toString().trim() : "";
      let nome = (colNome >= 0 && row[colNome]) ? row[colNome].toString().trim() : "";
      if ((!cat || !nome) && catalogoMap[matId]) {
        if (!cat) cat = catalogoMap[matId].categoria;
        if (!nome) nome = catalogoMap[matId].nome;
      }

      const qta = (colQta >= 0 && row[colQta] !== "") ? (parseInt(row[colQta], 10) || 1) : 1;
      const spuntaRaw = (colSpunta >= 0 && row[colSpunta]) ? row[colSpunta].toString().trim().toUpperCase() : "";
      const isSpunta = (spuntaRaw === "SI" || spuntaRaw === "1" || spuntaRaw === "TRUE");
      const qtaTornataRaw = (colQtaTornata >= 0 && row[colQtaTornata] !== "") ? parseInt(row[colQtaTornata], 10) : (isSpunta ? qta : "");

      rowsD.push([
        idDet,
        prelievoId,
        matId,
        cat,
        nome,
        qta,
        isSpunta ? "SI" : "NO",
        qtaTornataRaw,
        (colNote >= 0 && row[colNote]) ? row[colNote].toString().trim() : "",
        (colAgg >= 0 && row[colAgg]) ? row[colAgg].toString().trim() : Utilities.formatDate(new Date(), Session.getScriptTimeZone(), "yyyy-MM-dd HH:mm:ss")
      ]);
    }
  }

  // Riscrittura pulita Foglio Dettagli
  sheetD.clear();
  sheetD.getRange(1, 1, 1, officialHeadersD.length).setValues([officialHeadersD]);
  if (rowsD.length > 0) {
    sheetD.getRange(2, 1, rowsD.length, officialHeadersD.length).setValues(rowsD);
  }
  styleHeader(sheetD, officialHeadersD.length);

  try {
    SpreadsheetApp.getUi().alert(
      "Allineamento completato con successo!\n\n" +
      "• Foglio Prelievi: " + rowsP.length + " schede riallineate\n" +
      "• Foglio Dettagli: " + rowsD.length + " articoli riallineati con anagrafica Catalogo\n" +
      "• Foglio Catalogo: 40 materiali ufficiali pronti."
    );
  } catch (e) {
    // Modalità headless
  }
}

/**
 * Popola il foglio catalogo con i 40 materiali ufficiali dello Speleo Club Roma
 */
function popolaCatalogoUfficiale(sheetC) {
  const catalogRows = [
    ["C_001", "Corde", "Corde"],
    ["C_002", "Corde", "Cordini"],
    ["C_003", "Corde", "Sacchi"],
    ["C_004", "Corde", "Guaine"],
    ["A_001", "Armo", "Mosch. ghiera"],
    ["A_002", "Armo", "Moschettoni"],
    ["A_003", "Armo", "Maglie"],
    ["A_004", "Armo", "Anelli"],
    ["A_005", "Armo", "Piastrine"],
    ["A_006", "Armo", "Sacca d'armo"],
    ["A_007", "Armo", "Mazzette"],
    ["A_008", "Armo", "Scalpelli"],
    ["A_009", "Armo", "Palanchini"],
    ["T_001", "Trapano", "Heinell"],
    ["T_002", "Trapano", "Hilti"],
    ["T_003", "Trapano", "Milwakee"],
    ["T_004", "Trapano", "Bosh 12"],
    ["T_005", "Trapano", "Bosh 24"],
    ["T_006", "Trapano", "Batterie"],
    ["T_007", "Trapano", "Caricabatterie"],
    ["D_001", "Disostr.", "Punte 6mm"],
    ["D_002", "Disostr.", "Punte 8mm"],
    ["D_003", "Disostr.", "Punte 12mm"],
    ["E_001", "Attrezzature", "Attrezzature complete"],
    ["E_002", "Attrezzature", "Caschi"],
    ["E_003", "Attrezzature", "Imbraghi"],
    ["E_004", "Attrezzature", "Delta"],
    ["E_005", "Attrezzature", "Croll"],
    ["E_006", "Attrezzature", "Maniglie"],
    ["E_007", "Attrezzature", "Discensori"],
    ["E_008", "Attrezzature", "Pedali"],
    ["E_009", "Attrezzature", "Longes"],
    ["E_010", "Attrezzature", "Moschettoni (3)"],
    ["E_011", "Attrezzature", "Mosch. ghiera (1)"],
    ["E_012", "Attrezzature", "Maglie (1)"],
    ["R_001", "Rilievo", "Bussole"],
    ["R_002", "Rilievo", "Clisimetro"],
    ["R_003", "Rilievo", "Fettucce"],
    ["R_004", "Rilievo", "DistoX"],
    ["R_005", "Rilievo", "Taccuini"]
  ];
  sheetC.getRange(2, 1, catalogRows.length, 3).setValues(catalogRows);
}

/**
 * Formatta graficamente l'intestazione della tabella (grigio scuro, testo bianco in grassetto, blocca riga 1)
 */
function styleHeader(sheet, numColumns) {
  const headerRange = sheet.getRange(1, 1, 1, numColumns);
  headerRange.setBackground("#37474F");
  headerRange.setFontColor("#FFFFFF");
  headerRange.setFontWeight("bold");
  sheet.setFrozenRows(1);
}

/**
 * Helper per generare risposte JSON con MIME type corretto
 */
function jsonResponse(data, statusCode) {
  const output = ContentService.createTextOutput(JSON.stringify(data));
  output.setMimeType(ContentService.MimeType.JSON);
  return output;
}

/**
 * Cerca l'indice di una colonna controllando diverse possibili intestazioni
 */
function findColIndex(headers, possibleNames, defaultIndex) {
  for (let i = 0; i < headers.length; i++) {
    const h = headers[i];
    for (let p = 0; p < possibleNames.length; p++) {
      if (h === possibleNames[p]) return i;
    }
  }
  return defaultIndex;
}
