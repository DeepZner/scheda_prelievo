/**
 * GOOGLE APPS SCRIPT - SPELEO CLUB ROMA
 * Webhook per Sincronizzazione Magazzino Speleo (Offline-First Flutter App)
 * 
 * ISTRUZIONI DI INSTALLAZIONE / AGGIORNAMENTO:
 * 1. Apri il tuo foglio Google Sheets su Google Drive.
 * 2. Nel menu in alto clicca su "Estensioni" -> "Apps Script".
 * 3. Seleziona tutto il codice esistente nell'editor (Ctrl+A o Cmd+A) e cancellalo.
 * 4. Incolla questo codice integrale.
 * 5. Clicca sull'icona del "Dischetto" (Salva) o premi Ctrl+S.
 * 6. Nella barra in alto, a fianco del tasto "Esegui", seleziona dal menu a tendina
 *    la funzione "correggiEFormattaTuttiIFogli" e clicca su "Esegui".
 *    (Se Google chiede l'autorizzazione all'accesso al foglio, conferma con il tuo account).
 * 7. Torna al foglio: vedrai tutti i fogli e colonne allineati e formattati automaticamente!
 * 8. Nel menu in alto "Speleo Magazzino":
 *    - "💾 Esegui Backup Adesso (1-Click)": crea subito una copia Sheets ed esporta Excel (.xlsx).
 *    - "⏰ Attiva/Verifica Backup Notturno Automatico": attiva lo snapshot notturno automatico delle 03:00.
 * 9. Per aggiornare la Web App usata dallo smartphone:
 *    - In alto a destra clicca "Distribuisci" -> "Gestisci distribuzioni".
 *    - Clicca sull'icona della matita (Modifica).
 *    - Nel menu a tendina "Versione" seleziona "Nuova versione".
 *    - Assicurati che "Chi ha accesso" sia "Chiunque".
 *    - Clicca su "Distribuisci".
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
      .addSeparator()
      .addItem("💾 Esegui Backup Adesso (1-Click)", "menuEseguiBackupManuale")
      .addItem("⏰ Attiva/Verifica Backup Notturno Automatico", "menuConfiguraBackupNotturno")
      .addToUi();
  } catch (e) {
    // Non disponibile in contesti trigger headless
  }
}

/**
 * Gestione richieste GET (Health check / Ping / Scaricamento Catalogo / Scaricamento Prelievi / Visualizzazione Web Scheda)
 */
function doGet(e) {
  try {
    const schedaId = (e && e.parameter && (e.parameter.scheda || e.parameter.id)) 
      ? (e.parameter.scheda || e.parameter.id).toString().trim() 
      : null;
    const action = (e && e.parameter && e.parameter.action) 
      ? e.parameter.action 
      : (schedaId ? "view_scheda" : "ping");
    const ss = SpreadsheetApp.getActiveSpreadsheet();

    // Visualizzazione Web Scheda Prelievo (accessibile da qualsiasi browser senza app)
    if (action === "view_scheda" || (schedaId && action === "view")) {
      return renderSchedaHtml(ss, schedaId);
    }

    if (action === "ping") {
      return jsonResponse({
        status: "ok",
        message: "Connessione a Google Sheets attiva!",
        spreadsheet_name: ss.getName(),
        timestamp: new Date().toISOString()
      });
    }

    // Esecuzione backup on-demand via Web API
    if (action === "backup") {
      const resBackup = eseguiBackupCompleto(ss, "MANUALE_API");
      return jsonResponse({
        status: "ok",
        message: "Backup completato con successo!",
        backup: resBackup
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
          const headerP = dataP[0].map(function(h) { return h.toString().toLowerCase().trim(); });
          
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
          const headerD = dataD[0].map(function(h) { return h.toString().toLowerCase().trim(); });
          
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
 * Esegue il rendering HTML di una Scheda Prelievo per la consultazione Web da smartphone/desktop senza app
 */
function renderSchedaHtml(ss, schedaId) {
  const sheetP = ss.getSheetByName(SHEET_PRELIEVI);
  const sheetD = ss.getSheetByName(SHEET_DETTAGLI);
  const sheetC = ss.getSheetByName(SHEET_CATALOGO);

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

  let prelievo = null;
  if (sheetP) {
    const dataP = sheetP.getDataRange().getValues();
    if (dataP.length > 1) {
      const headerP = dataP[0].map(function(h) { return h.toString().toLowerCase().trim(); });
      const colId = findColIndex(headerP, ["id", "id_prelievo", "id prelievo"], -1);
      const colData = findColIndex(headerP, ["data", "data prelievo", "data di prelievo"], -1);
      const colLuogo = findColIndex(headerP, ["luogo", "luogo / grotta", "luogo/grotta"], -1);
      const colResp = findColIndex(headerP, ["responsabile"], -1);
      const colStato = findColIndex(headerP, ["stato"], -1);
      const colRiconsegna = findColIndex(headerP, ["data di riconsegna", "data riconsegna", "data rientro", "data_rientro", "riconsegna"], -1);
      const colOperatore = findColIndex(headerP, ["operatore", "operatore rientro", "operatore_rientro"], -1);
      const colParere = findColIndex(headerP, ["parere", "note / parere", "note/parere", "note"], -1);

      for (let i = 1; i < dataP.length; i++) {
        const row = dataP[i];
        const rowId = (colId >= 0 && row[colId]) ? row[colId].toString().trim() : "";
        if (rowId === schedaId) {
          prelievo = {
            id: rowId,
            dataPrelievo: (colData >= 0 && row[colData]) ? row[colData].toString().trim() : "",
            luogoGrotta: (colLuogo >= 0 && row[colLuogo]) ? row[colLuogo].toString().trim() : "Non specificato",
            responsabile: (colResp >= 0 && row[colResp]) ? row[colResp].toString().trim() : "Non specificato",
            stato: (colStato >= 0 && row[colStato]) ? row[colStato].toString().trim() : "In attesa materiale",
            dataRiconsegna: (colRiconsegna >= 0 && row[colRiconsegna]) ? row[colRiconsegna].toString().trim() : "",
            operatore: (colOperatore >= 0 && row[colOperatore]) ? row[colOperatore].toString().trim() : "",
            note: (colParere >= 0 && row[colParere]) ? row[colParere].toString().trim() : ""
          };
          break;
        }
      }
    }
  }

  if (!prelievo) {
    const notFoundHtml = '<!DOCTYPE html><html><head><meta charset="utf-8">' +
      '<meta name="viewport" content="width=device-width, initial-scale=1">' +
      '<title>Scheda non trovata - Speleo Club Roma</title>' +
      '<style>' +
      'body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: #faf8f5; color: #2c3e50; margin: 0; padding: 20px; text-align: center; }' +
      '.card { background: white; border-radius: 16px; padding: 36px 20px; max-width: 480px; margin: 40px auto; box-shadow: 0 4px 20px rgba(0,0,0,0.06); border: 1px solid #e2e8f0; }' +
      '.icon { font-size: 54px; margin-bottom: 16px; }' +
      'h2 { margin: 0 0 10px 0; color: #1e293b; font-size: 20px; }' +
      'p { color: #64748b; font-size: 14px; line-height: 1.6; }' +
      'code { background: #f1f5f9; padding: 3px 6px; border-radius: 6px; font-size: 12px; }' +
      '</style></head><body>' +
      '<div class="card">' +
      '<div class="icon">🔍</div>' +
      '<h2>Scheda Prelievo non trovata</h2>' +
      '<p>La scheda richiesta (<code>' + escapeHtml(schedaId || "") + '</code>) non è ancora presente sul foglio Google Sheets del magazzino.<br><br>Se è stata appena compilata sullo smartphone, assicurati che il magazziniere abbia completato la <strong>sincronizzazione</strong>.</p>' +
      '</div></body></html>';
    return HtmlService.createHtmlOutput(notFoundHtml).setTitle("Scheda non trovata").addMetaTag("viewport", "width=device-width, initial-scale=1");
  }

  const dettagli = [];
  if (sheetD) {
    const dataD = sheetD.getDataRange().getValues();
    if (dataD.length > 1) {
      const headerD = dataD[0].map(function(h) { return h.toString().toLowerCase().trim(); });
      const colPId = findColIndex(headerD, ["prelievo_id", "id prelievo", "id_prelievo", "prelievo id"], -1);
      const colMId = findColIndex(headerD, ["materiale_id", "id materiale", "id_materiale", "materiale id", "id_attrezzatura"], -1);
      const colQta = findColIndex(headerD, ["quantita_prelevata", "quantita", "quantità", "qta prelevata", "qta"], -1);
      const colSpunta = findColIndex(headerD, ["spunta_rientro", "spunta rientro", "rientrato", "rientro", "spunta"], -1);
      const colQtaTornata = findColIndex(headerD, ["qta_tornata", "qta tornata", "quantita tornata", "quantita_tornata", "restituiti"], -1);
      const colNoteD = findColIndex(headerD, ["note_rientro", "note rientro", "note"], -1);

      for (let i = 1; i < dataD.length; i++) {
        const row = dataD[i];
        const rPrelievoId = (colPId >= 0 && row[colPId]) ? row[colPId].toString().trim() : "";
        if (rPrelievoId === schedaId) {
          const matId = (colMId >= 0 && row[colMId]) ? row[colMId].toString().trim() : "";
          const cat = catalogoMap[matId] ? catalogoMap[matId].categoria : "";
          const nome = catalogoMap[matId] ? catalogoMap[matId].nome : matId;
          const qta = (colQta >= 0 && row[colQta] !== "") ? parseInt(row[colQta], 10) : 1;
          const spuntaRaw = (colSpunta >= 0 && row[colSpunta]) ? row[colSpunta].toString().trim().toUpperCase() : "";
          const isSpunta = (spuntaRaw === "SI" || spuntaRaw === "1" || spuntaRaw === "TRUE");
          const qtaTornata = (colQtaTornata >= 0 && row[colQtaTornata] !== "") ? parseInt(row[colQtaTornata], 10) : null;
          const noteD = (colNoteD >= 0 && row[colNoteD]) ? row[colNoteD].toString().trim() : "";

          const isMetri = (matId.toLowerCase() === "c_001" || matId.toLowerCase() === "r_003" || (cat.toLowerCase() === "corde" && !nome.toLowerCase().includes("cordin") && !nome.toLowerCase().includes("sacch") && !nome.toLowerCase().includes("guain")));
          const unita = isMetri ? "m" : "pz";

          dettagli.push({
            matId: matId,
            categoria: cat || "Varie",
            nome: nome,
            qta: isNaN(qta) ? 1 : qta,
            unita: unita,
            isMetri: isMetri,
            isSpunta: isSpunta,
            qtaTornata: isNaN(qtaTornata) ? null : qtaTornata,
            note: noteD
          });
        }
      }
    }
  }

  const html = buildSchedaHtmlOutput(prelievo, dettagli);
  return HtmlService.createHtmlOutput(html)
    .setTitle("Scheda: " + prelievo.luogoGrotta + " - Speleo Club Roma")
    .addMetaTag("viewport", "width=device-width, initial-scale=1");
}

function buildSchedaHtmlOutput(prelievo, dettagli) {
  let totPezzi = 0;
  let totMetri = 0;
  let totMatasse = 0;

  for (let i = 0; i < dettagli.length; i++) {
    const d = dettagli[i];
    if (d.isMetri) {
      totMetri += d.qta;
      totMatasse += 1;
      totPezzi += 1;
    } else {
      totPezzi += d.qta;
    }
  }

  let statoClass = "stato-attesa";
  let statoLabel = prelievo.stato;
  const sLower = prelievo.stato.toLowerCase();
  if (sLower.includes("rientrato")) {
    statoClass = "stato-rientrato";
  } else if (sLower.includes("mancante")) {
    statoClass = "stato-mancante";
  } else if (sLower.includes("annullat")) {
    statoClass = "stato-annullato";
  }

  let righeHtml = "";
  if (dettagli.length === 0) {
    righeHtml = '<tr><td colspan="5" style="text-align:center; padding: 24px; color: #94a3b8;">Nessun materiale specificato in questa scheda.</td></tr>';
  } else {
    for (let i = 0; i < dettagli.length; i++) {
      const d = dettagli[i];
      const rientratoBadge = d.isSpunta
        ? '<span class="badge-ok">✓ Rientrato' + (d.qtaTornata !== null ? ' (' + d.qtaTornata + ' ' + d.unita + ')' : '') + '</span>'
        : '<span class="badge-attesa">In uscita</span>';
      
      righeHtml += '<tr>' +
        '<td class="td-cat">' + escapeHtml(d.categoria) + '</td>' +
        '<td class="td-nome"><strong>' + escapeHtml(d.nome) + '</strong>' + (d.note ? '<div class="item-note">Nota: ' + escapeHtml(d.note) + '</div>' : '') + '</td>' +
        '<td class="td-qta ' + (d.isMetri ? 'qta-metri' : '') + '">' + d.qta + ' ' + d.unita + '</td>' +
        '<td class="td-rientro">' + rientratoBadge + '</td>' +
        '</tr>';
    }
  }

  return '<!DOCTYPE html><html><head><meta charset="utf-8">' +
    '<meta name="viewport" content="width=device-width, initial-scale=1">' +
    '<title>' + escapeHtml(prelievo.luogoGrotta) + ' - Speleo Club Roma</title>' +
    '<style>' +
    '* { box-sizing: border-box; }' +
    'body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; background: #f8fafc; color: #1e293b; margin: 0; padding: 16px; font-size: 14px; line-height: 1.5; }' +
    '.container { max-width: 680px; margin: 0 auto; background: white; border-radius: 16px; box-shadow: 0 4px 20px rgba(0,0,0,0.06); border: 1px solid #e2e8f0; overflow: hidden; }' +
    '.header { background: #0f172a; color: white; padding: 20px; display: flex; align-items: center; justify-content: space-between; }' +
    '.brand { display: flex; align-items: center; gap: 12px; }' +
    '.brand-title { font-size: 16px; font-weight: 700; letter-spacing: 0.5px; }' +
    '.brand-sub { font-size: 11px; color: #94a3b8; }' +
    '.btn-print { background: #334155; color: white; border: none; border-radius: 8px; padding: 8px 12px; font-size: 12px; font-weight: 600; cursor: pointer; }' +
    '.card-body { padding: 20px; }' +
    '.title-row { display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 12px; gap: 12px; }' +
    '.grotta-name { font-size: 22px; font-weight: 800; color: #0f172a; margin: 0; line-height: 1.2; }' +
    '.badge-stato { display: inline-block; padding: 6px 12px; border-radius: 999px; font-size: 11px; font-weight: 700; white-space: nowrap; text-transform: uppercase; letter-spacing: 0.5px; }' +
    '.stato-attesa { background: #fef3c7; color: #92400e; border: 1px solid #fde68a; }' +
    '.stato-rientrato { background: #dcfce7; color: #166534; border: 1px solid #bbf7d0; }' +
    '.stato-mancante { background: #fee2e2; color: #991b1b; border: 1px solid #fecaca; }' +
    '.stato-annullato { background: #f1f5f9; color: #475569; border: 1px solid #cbd5e1; }' +
    '.meta-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; background: #f8fafc; border-radius: 12px; padding: 14px; margin-bottom: 20px; border: 1px solid #f1f5f9; }' +
    '.meta-label { font-size: 11px; color: #64748b; font-weight: 600; text-transform: uppercase; margin-bottom: 2px; }' +
    '.meta-value { font-size: 14px; font-weight: 600; color: #1e293b; }' +
    '.note-box { background: #fffbeb; border: 1px solid #fef3c7; border-radius: 8px; padding: 10px 14px; margin-bottom: 20px; font-size: 13px; color: #78350f; }' +
    '.section-title { font-size: 14px; font-weight: 700; color: #334155; margin: 24px 0 10px 0; text-transform: uppercase; letter-spacing: 0.5px; display: flex; justify-content: space-between; align-items: center; }' +
    'table { width: 100%; border-collapse: collapse; font-size: 13px; }' +
    'th { background: #f1f5f9; text-align: left; padding: 10px 8px; font-weight: 700; color: #475569; font-size: 11px; text-transform: uppercase; border-bottom: 2px solid #e2e8f0; }' +
    'td { padding: 10px 8px; border-bottom: 1px solid #f1f5f9; vertical-align: top; }' +
    '.td-cat { color: #64748b; font-size: 11px; width: 22%; }' +
    '.td-nome { color: #0f172a; width: 40%; }' +
    '.td-qta { font-weight: 700; text-align: right; width: 18%; }' +
    '.qta-metri { color: #c2410c; }' +
    '.td-rientro { text-align: right; width: 20%; }' +
    '.badge-ok { background: #dcfce7; color: #166534; font-size: 11px; font-weight: 700; padding: 2px 6px; border-radius: 4px; }' +
    '.badge-attesa { background: #fef3c7; color: #92400e; font-size: 11px; font-weight: 600; padding: 2px 6px; border-radius: 4px; }' +
    '.item-note { font-size: 11px; color: #b45309; font-style: italic; margin-top: 3px; }' +
    '.summary-box { display: flex; justify-content: space-around; background: #0f172a; color: white; padding: 14px; border-radius: 12px; margin-top: 20px; font-weight: 700; font-size: 13px; }' +
    '.summary-metri { color: #fdba74; }' +
    '.footer { text-align: center; color: #94a3b8; font-size: 11px; margin-top: 24px; padding-top: 16px; border-top: 1px solid #e2e8f0; }' +
    '@media print { body { background: white; padding: 0; } .container { box-shadow: none; border: none; max-width: 100%; } .btn-print { display: none; } }' +
    '</style></head><body>' +
    '<div class="container">' +
    '<div class="header">' +
    '<div class="brand">' +
    '<div><div class="brand-title">🦇 SPELEO CLUB ROMA 1959</div><div class="brand-sub">Scheda Prelievo Attrezzature & Materiali</div></div>' +
    '</div>' +
    '<button class="btn-print" onclick="window.print()">🖨️ Stampa / PDF</button>' +
    '</div>' +
    '<div class="card-body">' +
    '<div class="title-row">' +
    '<h1 class="grotta-name">' + escapeHtml(prelievo.luogoGrotta) + '</h1>' +
    '<span class="badge-stato ' + statoClass + '">' + escapeHtml(statoLabel) + '</span>' +
    '</div>' +
    '<div class="meta-grid">' +
    '<div><div class="meta-label">Responsabile Prelievo</div><div class="meta-value">👤 ' + escapeHtml(prelievo.responsabile) + '</div></div>' +
    '<div><div class="meta-label">Data Prelievo</div><div class="meta-value">📅 ' + escapeHtml(prelievo.dataPrelievo) + '</div></div>' +
    (prelievo.dataRiconsegna ? '<div><div class="meta-label">Data Riconsegna</div><div class="meta-value">🏁 ' + escapeHtml(prelievo.dataRiconsegna) + '</div></div>' : '') +
    (prelievo.operatore ? '<div><div class="meta-label">Operatore Magazzino</div><div class="meta-value">🏷️ ' + escapeHtml(prelievo.operatore) + '</div></div>' : '') +
    '</div>' +
    (prelievo.note ? '<div class="note-box"><strong>Note scheda:</strong> ' + escapeHtml(prelievo.note) + '</div>' : '') +
    '<div class="section-title"><span>Materiali Prelevati (' + dettagli.length + ' voci)</span></div>' +
    '<table><thead><tr><th>Categoria</th><th>Descrizione</th><th style="text-align:right;">Quantità</th><th style="text-align:right;">Rientro</th></tr></thead>' +
    '<tbody>' + righeHtml + '</tbody></table>' +
    '<div class="summary-box">' +
    '<div>Totale Pezzi Fisici: ' + totPezzi + ' pz</div>' +
    (totMetri > 0 ? '<div class="summary-metri">Corde: ' + totMetri + ' m (' + totMatasse + ' ' + (totMatasse === 1 ? 'matassa' : 'matasse') + ')</div>' : '') +
    '</div>' +
    '<div class="footer">ID Scheda: ' + escapeHtml(prelievo.id) + '<br>Speleo Club Roma • Gestione Magazzino Offline-First</div>' +
    '</div></div></body></html>';
}

function escapeHtml(str) {
  if (!str) return "";
  return str.toString()
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
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
      if (sheet.getMaxColumns() < idx + 1) {
        sheet.insertColumnsAfter(sheet.getMaxColumns(), (idx + 1) - sheet.getMaxColumns());
      }
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

    if (sheet.getMaxColumns() < rowLength) {
      sheet.insertColumnsAfter(sheet.getMaxColumns(), rowLength - sheet.getMaxColumns());
    }

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
      if (sheet.getMaxColumns() < idx + 1) {
        sheet.insertColumnsAfter(sheet.getMaxColumns(), (idx + 1) - sheet.getMaxColumns());
      }
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

    if (sheet.getMaxColumns() < rowLength) {
      sheet.insertColumnsAfter(sheet.getMaxColumns(), rowLength - sheet.getMaxColumns());
    }

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
    styleHeader(sheetP, headersP[0].length);
    sheetP.getRange(1, 1, 1, headersP[0].length).setValues(headersP);
  }

  let sheetD = ss.getSheetByName(SHEET_DETTAGLI);
  if (!sheetD) {
    sheetD = ss.insertSheet(SHEET_DETTAGLI);
    const headersD = [
      ["ID Dettaglio", "ID Prelievo", "ID Materiale", "Categoria", "Nome Materiale", "Q.tà Prelevata", "Spunta Rientro", "Q.tà Tornata", "Note Rientro", "Ultimo Aggiornamento"]
    ];
    styleHeader(sheetD, headersD[0].length);
    sheetD.getRange(1, 1, 1, headersD[0].length).setValues(headersD);
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

  // Snapshot di sicurezza pre-formattazione (Copia Sheets + Excel)
  try {
    eseguiBackupCompleto(ss, "PRE_FORMATTAZIONE");
  } catch (e) {
    console.warn("Attenzione: snapshot pre-formattazione non riuscito: " + e);
  }

  // 1. Assicura e formatta Foglio Catalogo
  let sheetC = ss.getSheetByName(SHEET_CATALOGO);
  if (!sheetC) {
    sheetC = ss.insertSheet(SHEET_CATALOGO);
  }
  const headersC = [["ID Materiale", "Categoria", "Nome Oggetto"]];
  styleHeader(sheetC, headersC[0].length);
  const dataC = sheetC.getDataRange().getValues();
  if (dataC.length === 0 || (dataC.length === 1 && !dataC[0][0])) {
    sheetC.getRange(1, 1, 1, headersC[0].length).setValues(headersC);
    popolaCatalogoUfficiale(sheetC);
  } else {
    sheetC.getRange(1, 1, 1, headersC[0].length).setValues(headersC);
  }

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
  styleHeader(sheetP, officialHeadersP.length);
  sheetP.getRange(1, 1, 1, officialHeadersP.length).setValues([officialHeadersP]);
  if (rowsP.length > 0) {
    if (sheetP.getMaxRows() < rowsP.length + 1) {
      sheetP.insertRowsAfter(sheetP.getMaxRows(), (rowsP.length + 1) - sheetP.getMaxRows());
    }
    sheetP.getRange(2, 1, rowsP.length, officialHeadersP.length).setValues(rowsP);
  }
  try {
    sheetP.autoResizeColumns(1, officialHeadersP.length);
  } catch (e) {}

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
  styleHeader(sheetD, officialHeadersD.length);
  sheetD.getRange(1, 1, 1, officialHeadersD.length).setValues([officialHeadersD]);
  if (rowsD.length > 0) {
    if (sheetD.getMaxRows() < rowsD.length + 1) {
      sheetD.insertRowsAfter(sheetD.getMaxRows(), (rowsD.length + 1) - sheetD.getMaxRows());
    }
    sheetD.getRange(2, 1, rowsD.length, officialHeadersD.length).setValues(rowsD);
  }
  try {
    sheetD.autoResizeColumns(1, officialHeadersD.length);
  } catch (e) {}

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
  if (sheetC.getMaxColumns() < 3) {
    sheetC.insertColumnsAfter(sheetC.getMaxColumns(), 3 - sheetC.getMaxColumns());
  }
  if (sheetC.getMaxRows() < catalogRows.length + 1) {
    sheetC.insertRowsAfter(sheetC.getMaxRows(), (catalogRows.length + 1) - sheetC.getMaxRows());
  }
  sheetC.getRange(2, 1, catalogRows.length, 3).setValues(catalogRows);
  try {
    sheetC.autoResizeColumns(1, 3);
  } catch (e) {}
}

/**
 * Formatta graficamente l'intestazione della tabella (grigio scuro, testo bianco in grassetto, blocca riga 1)
 */
function styleHeader(sheet, numColumns) {
  if (sheet.getMaxColumns() < numColumns) {
    sheet.insertColumnsAfter(sheet.getMaxColumns(), numColumns - sheet.getMaxColumns());
  }
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

// ============================================================================
// MODULO BACKUP & DISASTER RECOVERY (GOOGLE DRIVE + EXCEL .XLSX)
// ============================================================================

// Nome della cartella di backup creata automaticamente all'interno della cartella del foglio
const BACKUP_FOLDER_NAME = "Magazzino Speleo - Backup";
// Giorni di retention per i backup automatici ordinari
const BACKUP_RETENTION_DAYS = 30;

/**
 * Ottiene o crea la cartella di backup su Google Drive
 * (posizionata all'interno della stessa cartella genitore in cui risiede il foglio principale)
 */
function getOrCreateBackupFolder(ss) {
  try {
    const file = DriveApp.getFileById(ss.getId());
    const parents = file.getParents();
    const parentFolder = parents.hasNext() ? parents.next() : DriveApp.getRootFolder();

    const subfolders = parentFolder.getFoldersByName(BACKUP_FOLDER_NAME);
    if (subfolders.hasNext()) {
      return subfolders.next();
    }
    return parentFolder.createFolder(BACKUP_FOLDER_NAME);
  } catch (e) {
    const rootSubfolders = DriveApp.getFoldersByName(BACKUP_FOLDER_NAME);
    if (rootSubfolders.hasNext()) {
      return rootSubfolders.next();
    }
    return DriveApp.createFolder(BACKUP_FOLDER_NAME);
  }
}

/**
 * Esegue il backup completo:
 * 1. Snapshot copia nativa Google Sheets
 * 2. Esportazione offline Microsoft Excel (.xlsx)
 * 3. Rotazione automatica delle copie obsolete (Retention a 30 giorni)
 * 
 * @param {Spreadsheet} ss - Il foglio attivo
 * @param {string} tipo - "AUTOMATICO", "MANUALE" o "PRE_FORMATTAZIONE"
 * @return {object} Dettagli del backup creato
 */
function eseguiBackupCompleto(ss, tipo) {
  if (!ss) {
    ss = SpreadsheetApp.getActiveSpreadsheet();
  }
  const file = DriveApp.getFileById(ss.getId());
  const backupFolder = getOrCreateBackupFolder(ss);

  // Formatta data e ora corrente: YYYY-MM-DD_HHmm
  const now = new Date();
  const pad = function(n) { return (n < 10 ? "0" : "") + n; };
  const timestampStr = now.getFullYear() + "-" +
    pad(now.getMonth() + 1) + "-" +
    pad(now.getDate()) + "_" +
    pad(now.getHours()) + "" +
    pad(now.getMinutes());

  const tagTipo = tipo ? "_" + tipo : "";
  const baseName = "Backup_Magazzino_" + timestampStr + tagTipo;

  // 1. Snapshot copia nativa Google Sheets
  const sheetCopy = file.makeCopy(baseName, backupFolder);

  // 2. Esportazione offline Microsoft Excel (.xlsx)
  let xlsxFile = null;
  try {
    const url = "https://docs.google.com/spreadsheets/d/" + ss.getId() + "/export?format=xlsx";
    const res = UrlFetchApp.fetch(url, {
      method: "get",
      headers: { "Authorization": "Bearer " + ScriptApp.getOAuthToken() },
      muteHttpExceptions: true
    });
    if (res.getResponseCode() === 200) {
      const blob = res.getBlob().setName(baseName + ".xlsx");
      xlsxFile = backupFolder.createFile(blob);
    }
  } catch (eXlsx) {
    console.warn("Esportazione Excel non riuscita: " + eXlsx);
  }

  // 3. Esegui la rotazione automatica dei vecchi backup (Retention Policy)
  let eliminatiCount = 0;
  try {
    eliminatiCount = eseguiRotazioneBackup(backupFolder);
  } catch (eRot) {
    console.warn("Rotazione backup non riuscita: " + eRot);
  }

  return {
    success: true,
    timestamp: timestampStr,
    sheetName: sheetCopy.getName(),
    sheetUrl: sheetCopy.getUrl(),
    xlsxName: xlsxFile ? xlsxFile.getName() : null,
    folderName: backupFolder.getName(),
    folderUrl: backupFolder.getUrl(),
    eliminatiCount: eliminatiCount
  };
}

/**
 * Elimina i file di backup automatico più vecchi di BACKUP_RETENTION_DAYS giorni,
 * preservando i backup mensili (del 1° del mese fino a 365 giorni) e quelli manuali o pre-formattazione (90 giorni).
 */
function eseguiRotazioneBackup(backupFolder) {
  const files = backupFolder.getFiles();
  const cutoffTime = new Date().getTime() - (BACKUP_RETENTION_DAYS * 24 * 60 * 60 * 1000);
  let eliminati = 0;

  while (files.hasNext()) {
    const f = files.next();
    const name = f.getName();
    const created = f.getDateCreated();

    // Preserva i backup manuali o pre-formattazione per almeno 90 giorni
    if (name.includes("_MANUALE") || name.includes("_PRE_FORMATTAZIONE")) {
      const manualCutoff = new Date().getTime() - (90 * 24 * 60 * 60 * 1000);
      if (created.getTime() < manualCutoff) {
        f.setTrashed(true);
        eliminati++;
      }
      continue;
    }

    // Preserva i backup del 1° del mese per 1 anno (365 giorni)
    const matchDay = name.match(/_(\d{4}-\d{2}-01)_/);
    if (matchDay) {
      const yearlyCutoff = new Date().getTime() - (365 * 24 * 60 * 60 * 1000);
      if (created.getTime() < yearlyCutoff) {
        f.setTrashed(true);
        eliminati++;
      }
      continue;
    }

    // Elimina i backup automatici ordinari più vecchi del periodo di retention
    if (created.getTime() < cutoffTime) {
      f.setTrashed(true);
      eliminati++;
    }
  }
  return eliminati;
}

/**
 * Handler per la voce di menu "💾 Esegui Backup Adesso (1-Click)"
 */
function menuEseguiBackupManuale() {
  const ui = SpreadsheetApp.getUi();
  try {
    const ss = SpreadsheetApp.getActiveSpreadsheet();
    ui.toast("Creazione backup in corso (Google Sheets + Excel)...", "Backup Magazzino", 5);
    const res = eseguiBackupCompleto(ss, "MANUALE");

    let msg = "✅ Backup completato con successo!\n\n" +
      "Cartella: " + res.folderName + "\n" +
      "• Copia Google Sheets: " + res.sheetName + "\n";
    if (res.xlsxName) {
      msg += "• Copia Excel: " + res.xlsxName + "\n";
    }
    if (res.eliminatiCount > 0) {
      msg += "\nRotazione: rimossi " + res.eliminatiCount + " file obsoleti (> 30gg).";
    }
    ui.alert("Backup Magazzino Speleo", msg, ui.ButtonSet.OK);
  } catch (err) {
    ui.alert("Errore Backup", "Impossibile completare il backup:\n" + err.toString(), ui.ButtonSet.OK);
  }
}

/**
 * Handler per la voce di menu "⏰ Attiva/Verifica Backup Notturno Automatico"
 */
function menuConfiguraBackupNotturno() {
  const ui = SpreadsheetApp.getUi();
  try {
    const triggers = ScriptApp.getProjectTriggers();
    let triggerAttivo = false;
    for (let i = 0; i < triggers.length; i++) {
      if (triggers[i].getHandlerFunction() === "triggerBackupNotturno") {
        triggerAttivo = true;
        break;
      }
    }

    if (triggerAttivo) {
      const resp = ui.alert(
        "Backup Notturno Attivo",
        "Il trigger automatico notturno è già configurato ed attivo!\n\n" +
        "Viene eseguito ogni notte tra le 02:00 e le 04:00, salvando copia Google Sheets + Excel nella cartella 'Magazzino Speleo - Backup'.\n\n" +
        "Vuoi reinstallarlo per rinnovare i permessi?",
        ui.ButtonSet.YES_NO
      );
      if (resp !== ui.Button.YES) return;
    }

    installaTriggerBackupNotturno();
    ui.alert(
      "Configurazione Riuscita",
      "✅ Trigger notturno installato con successo!\n\n" +
      "Ogni notte alle 03:00 verrà creato automaticamente un nuovo snapshot (Sheets + Excel) con rotazione a 30 giorni.",
      ui.ButtonSet.OK
    );
  } catch (err) {
    ui.alert("Errore Trigger", "Impossibile configurare il trigger notturno:\n" + err.toString(), ui.ButtonSet.OK);
  }
}

/**
 * Installa il trigger temporale programmato per eseguire il backup notturno ogni notte alle ore 03:00
 */
function installaTriggerBackupNotturno() {
  const triggers = ScriptApp.getProjectTriggers();
  for (let i = 0; i < triggers.length; i++) {
    if (triggers[i].getHandlerFunction() === "triggerBackupNotturno") {
      ScriptApp.deleteTrigger(triggers[i]);
    }
  }

  ScriptApp.newTrigger("triggerBackupNotturno")
    .timeBased()
    .everyDays(1)
    .atHour(3)
    .create();
}

/**
 * Funzione invocata automaticamente dal trigger temporale notturno
 */
function triggerBackupNotturno() {
  try {
    const ss = SpreadsheetApp.getActiveSpreadsheet();
    eseguiBackupCompleto(ss, "AUTOMATICO");
    console.log("Backup notturno completato regolarmente.");
  } catch (err) {
    console.error("Errore durante il backup notturno: " + err);
    try {
      const ownerEmail = Session.getEffectiveUser().getEmail();
      if (ownerEmail) {
        MailApp.sendEmail(
          ownerEmail,
          "⚠️ Errore Backup Notturno - Speleo Club Roma",
          "Si è verificato un errore durante l'esecuzione del backup automatico del foglio Magazzino Speleo:\n\n" +
          err.toString() + "\n\n" +
          "Timestamp: " + new Date().toISOString()
        );
      }
    } catch (mailErr) {
      console.error("Invio email di avviso fallito: " + mailErr);
    }
  }
}
