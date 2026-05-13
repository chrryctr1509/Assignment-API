---
name: ms-addin-testing
description: "Office Add-in sideload testing, JS API patterns, taskpane interaction"
---

# MS Office Add-in Testing Skill

## PURPOSE
Panduan untuk environment-matrix-runner dan qa-tester dalam menjalankan tests untuk Microsoft Office Add-ins.

## SIDELOAD TESTING

### Prerequisites
- Office desktop app (Word, Excel, PowerPoint, Outlook)
- Node.js untuk development server
- manifest.xml yang valid

### Sideload Steps
1. Start dev server: `npm start` (biasanya port 3000)
2. Office app → Insert → My Add-ins → Upload My Add-in
3. Browse ke manifest.xml
4. Add-in muncul di taskpane

### Automated Sideload (Windows)
```bash
# Excel
npx office-addin-debugging start manifest.xml

# Word  
npx office-addin-debugging start manifest.xml --app word
```

## OFFICE JS API TESTING

### Common API Patterns
```javascript
// Excel — read range
await Excel.run(async (context) => {
  const range = context.workbook.worksheets.getActiveWorksheet().getRange("A1:B10");
  range.load("values");
  await context.sync();
  console.log(range.values);
});

// Word — insert text
await Word.run(async (context) => {
  const body = context.document.body;
  body.insertText("Hello", Word.InsertLocation.end);
  await context.sync();
});
```

### Test Assertions
```javascript
// Verify cell value
Excel.run(async (ctx) => {
  const cell = ctx.workbook.worksheets.getActiveWorksheet().getRange("A1");
  cell.load("values");
  await ctx.sync();
  assert.equal(cell.values[0][0], expectedValue);
});
```

## TASKPANE INTERACTION PATTERNS

### Health Check
1. Verify taskpane loads (no blank screen)
2. Verify API connection (Office.onReady fires)
3. Verify auth flow (if applicable)

### Functional Testing
1. **Input → Process → Output**: 
   - User inputs data in taskpane
   - Add-in processes via Office JS API
   - Result appears in document/spreadsheet
2. **Document → Taskpane**:
   - Select range in document
   - Taskpane reflects selection
3. **Taskpane → External API**:
   - Taskpane calls backend API
   - Results rendered in taskpane or document

## OFFICE CONSOLE vs BROWSER CONSOLE

### Key Differences
| Feature | Browser Console | Office Console |
|---------|----------------|----------------|
| Access | F12 / DevTools | Office app → F12 (Windows) |
| Network tab | Full | Limited |
| localStorage | Standard | Sandboxed per add-in |
| Cookies | Standard | Restricted |
| CORS | Standard | Office-specific CORS rules |

### Debugging in Office
```javascript
// Use console.log extensively
console.log("[ADDIN] Step 1: Loading data...");

// Office-specific error handling
Office.onReady((info) => {
  if (info.host === Office.HostType.Excel) {
    console.log("[ADDIN] Running in Excel");
  }
}).catch((error) => {
  console.error("[ADDIN] Office.onReady failed:", error);
});
```

## TEST CHECKLIST FOR ADD-INS
- [ ] Manifest validates (npx office-addin-manifest validate manifest.xml)
- [ ] Taskpane loads without errors
- [ ] Office.onReady fires successfully
- [ ] Core functionality works (read/write to document)
- [ ] Error handling for offline/disconnected state
- [ ] Auth flow completes (if applicable)
- [ ] Sideload works on target Office apps
- [ ] Performance: taskpane responsive within 3 seconds
