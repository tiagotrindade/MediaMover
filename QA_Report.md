# QA Report — PhotoMoveApp
**Engenheiro**: QA Engineer Sénior (Swift/macOS)
**Data**: 2026-03-13
**Ficheiros analisados**: `FileOrganizer.swift`, `MetadataExtractor.swift`, `FileHashing.swift`, `OperationRecord.swift`, `MediaFile.swift`, `OrganizationPattern.swift`

---

## PARTE 1 — Bugs Críticos em FileOrganizer.swift

Formato: **[FICHEIRO] → [ISSUE] → [IMPACTO] → [FIX]**

---

### 🔴 BUG-01 — Integrity Check no modo Move é uma falsa garantia (CRÍTICO)

**[FICHEIRO]** `FileOrganizer.swift` linhas 231–242 (`verifyIntegrity`) + linha 194 (chamada)

**[ISSUE]**
A função `verifyIntegrity` para o modo `.move` nunca compara hashes — apenas lê o ficheiro de destino e retorna `true` incondicionalmente:

```swift
// ❌ CÓDIGO ACTUAL — sempre retorna true em modo Move
if mode == .move {
    _ = try FileHashing.hash(of: destination, algorithm: algorithm)
    return true  // ← nunca detecta corrupção!
}
```

Além disso, a chamada na linha 194 passa `source: targetURL` quando é um move (source == destination), tornando a comparação de hashes impossível mesmo que a lógica fosse corrigida:

```swift
// ❌ CÓDIGO ACTUAL — source e destination são o mesmo URL em modo Move
let verified = try verifyIntegrity(
    source: config.mode == .copy ? file.url : targetURL,  // ← targetURL em move!
    destination: targetURL,
    ...
)
```

**[IMPACTO]**
Corrupção silenciosa de dados. Um ficheiro pode ser transferido com bits corrompidos (disco com bad sectors, I/O error parcial), e a app reporta `verifiedFiles += 1` como se tudo estivesse correcto. O utilizador pensa que os ficheiros estão íntegros quando podem estar destruídos — sem possibilidade de recuperação pois o original foi apagado pelo move.

**[FIX]**
O hash da fonte tem de ser calculado **antes** do move, guardado em memória, e comparado com o hash do destino **após** o move. Isso implica:

1. Calcular `sourceHash` antes de `fm.moveItem`.
2. Passar o `sourceHash` pré-calculado para a verificação pós-move.
3. Comparar `sourceHash == destHash` em vez de retornar `true`.

```swift
// ✅ LÓGICA CORRECTA (pseudocódigo)
// Antes do move:
let preHash = config.verifyIntegrity ? try FileHashing.hash(of: file.url, algorithm: config.hashAlgorithm) : nil

// Depois do move:
if let preHash {
    let postHash = try FileHashing.hash(of: targetURL, algorithm: config.hashAlgorithm)
    let verified = preHash == postHash
    // ...
}
```

---

### 🔴 BUG-02 — `skippedDuplicates` usado incorrectamente para "sem data" (CRÍTICO — dados corrompidos)

**[FICHEIRO]** `FileOrganizer.swift` linha 69

**[ISSUE]**
Quando um ficheiro não tem data disponível (nenhum EXIF e sem fallback configurado), o código incrementa `skippedDuplicates`:

```swift
// ❌ CÓDIGO ACTUAL
guard let effectiveDate = file.effectiveDate(fallback: config.dateFallback) else {
    result.skippedDuplicates += 1  // ← não é um duplicado!
    result.processedFiles += 1
    ...
    continue
}
```

**[IMPACTO]**
As estatísticas finais reportadas ao utilizador são enganosas: o contador de "duplicados ignorados" inclui ficheiros sem metadata de data, o que pode levar o utilizador a acreditar que tem mais duplicados do que realmente tem. Relatórios de auditoria ficam incorrectos.

**[FIX]**
Adicionar um contador dedicado `skippedNoDate: Int` em `OperationResult` e usar esse campo para ficheiros sem data. Alternativamente, adicionar ao array `errors` com uma mensagem descritiva.

---

### 🔴 BUG-03 — Duplicação de subpasta de câmera para padrões que já incluem Camera (CRÍTICO — estrutura de pastas incorrecta)

**[FICHEIRO]** `FileOrganizer.swift` linhas 75–86 + `OrganizationPattern.swift`

**[ISSUE]**
Os padrões `.yearMonthDayCamera`, `.yearMonthCamera` e `.cameraYearMonthDay` já incluem a câmera no subpath. Se o utilizador também activar `separateByCamera: true`, a câmera é adicionada **duas vezes** ao caminho:

```swift
// Exemplo com .yearMonthDayCamera + separateByCamera = true:
var subpath = config.pattern.destinationSubpath(...)
// → "2026/03/12/iPhone_15"

if config.separateByCamera, let camera = file.cameraModel, !camera.isEmpty {
    subpath += "/\(safeCam)"
    // → "2026/03/12/iPhone_15/iPhone_15"  ❌ duplicado!
}
```

**[IMPACTO]**
Pastas com nomes duplicados (`2026/03/12/iPhone_15/iPhone_15`). Ficheiros organizados de forma incorrecta. O utilizador não consegue navegar intuitivamente na estrutura de pastas.

**[FIX]**
Verificar se o padrão escolhido já inclui câmera antes de adicionar o subfolder adicional. Pode-se adicionar uma propriedade `includesCamera: Bool` ao enum `OrganizationPattern`, ou simplesmente ignorar `separateByCamera` quando o padrão já incorpora câmera.

---

### 🟠 BUG-04 — `try?` silencia erros críticos em `overwrite` (MÉDIO)

**[FICHEIRO]** `FileOrganizer.swift` linha 148

**[ISSUE]**
O `removeItem` usa `try?`, descartando silenciosamente erros de permissão ou file-lock:

```swift
case .overwrite:
    try? fm.removeItem(at: targetURL)  // ❌ erro ignorado silenciosamente
```

Se `removeItem` falhar (ficheiro bloqueado, sem permissões), o `copyItem`/`moveItem` subsequente falhará com um erro confuso como "file already exists" em vez do verdadeiro motivo (sem permissão).

**[IMPACTO]**
Diagnóstico difícil. O utilizador vê um erro genérico de "ficheiro já existe" sem perceber a causa raiz.

**[FIX]**
Usar `try fm.removeItem(at: targetURL)` com tratamento explícito do erro e mensagem descritiva antes de tentar a cópia/move.

---

### 🟠 BUG-05 — `successCount` inclui duplicados ignorados (MÉDIO — estatísticas enganosas)

**[FICHEIRO]** `OperationResult.swift` linha 16

**[ISSUE]**
```swift
var successCount: Int { processedFiles - errors.count }
```

`processedFiles` é incrementado para **todos** os casos (sucesso, erro, e skip). Assim, `successCount` inclui ficheiros que foram ignorados como duplicados, inflacionando a contagem de "sucesso".

**[IMPACTO]**
O utilizador vê "150 ficheiros processados com sucesso" quando na realidade 30 foram ignorados como duplicados e 120 foram realmente copiados/movidos.

**[FIX]**
```swift
var successCount: Int { processedFiles - errors.count - skippedDuplicates }
```

---

### 🟠 BUG-06 — `datePrefix` e `destinationSubpath` usam `Calendar.current` (MÉDIO — inconsistência de timezone)

**[FICHEIRO]** `FileOrganizer.swift` linha 248 + `OrganizationPattern.swift` linha 31

**[ISSUE]**
As datas EXIF (`"yyyy:MM:dd HH:mm:ss"`) são guardadas **sem informação de timezone**. Ao usar `Calendar.current` para extrair componentes, a interpretação depende do timezone do sistema operativo no momento da execução.

Exemplo: uma foto tirada em Lisboa (UTC+0) importada num Mac configurado para UTC-5 (Nova Iorque) pode ser organizada na pasta do dia anterior.

**[IMPACTO]**
Fotos do mesmo evento podem parar em pastas de dias diferentes dependendo do timezone do Mac onde a app corre. Problema especialmente visível em fotos tiradas perto da meia-noite.

**[FIX]**
Usar `Calendar(identifier: .gregorian)` com `timeZone = TimeZone(identifier: "UTC")` tanto em `datePrefix` como em `destinationSubpath`. Uma alternativa mais correcta seria preservar o timezone da câmera quando disponível (alguns ficheiros modernos têm timezone no EXIF `OffsetTimeOriginal`).

---

## PARTE 2 — Análise do Integrity Check no Modo Move

### Diagnóstico detalhado

O integrity check no modo Move está **completamente não-funcional** como verificação de integridade real. O fluxo actual é:

```
1. fm.moveItem(source → destination)   ← ficheiro original destruído
2. verifyIntegrity(source: destination, destination: destination, mode: .move)
3.   → FileHashing.hash(of: destination)  ← lê o destino
4.   → return true                         ← SEMPRE true se o ficheiro for legível
```

O que deveria acontecer:

```
1. sourceHash = FileHashing.hash(of: source)   ← ANTES do move
2. fm.moveItem(source → destination)
3. destHash = FileHashing.hash(of: destination)  ← DEPOIS do move
4. return sourceHash == destHash                  ← comparação real
```

### Risco operacional

Este bug é particularmente perigoso porque:
- O modo Move **destrói o ficheiro original** — não há segunda oportunidade
- A verificação dá uma **falsa sensação de segurança** — `verifiedFiles` é incrementado incorrectamente
- Em discos com problemas de I/O parcial, o ficheiro de destino pode existir e ser legível mas conter dados corrompidos

---

## PARTE 3 — Bugs no MetadataExtractor.swift

### 🟠 BUG-META-01 — Sem fallback para `DateTimeDigitized` (MÉDIO)

**[FICHEIRO]** `MetadataExtractor.swift` linha 22
**[ISSUE]** Apenas lê `kCGImagePropertyExifDateTimeOriginal`. Câmeras digitalizadoras (scanners) e alguns modelos antigos só preenchem `DateTimeDigitized`.
**[IMPACTO]** Fotos digitalizadas ficam sem data EXIF, forçando fallback para data de ficheiro (potencialmente incorrecta).
**[FIX]** Adicionar fallback: `DateTimeOriginal` → `DateTimeDigitized` → `TIFFDateTime`.

### 🟠 BUG-META-02 — Sem suporte a subsegundos no EXIF (MÉDIO)

**[FICHEIRO]** `MetadataExtractor.swift` linha 72
**[ISSUE]** O formato `"yyyy:MM:dd HH:mm:ss"` não suporta strings com subsegundos como `"2024:06:15 10:30:00.500"`.
**[IMPACTO]** Algumas câmeras (Nikon, Sony) escrevem subsegundos no `DateTimeOriginal` → parse falha → `dateTaken = nil`.
**[FIX]** Tentar parse com subsegundos primeiro (`"yyyy:MM:dd HH:mm:ss.SSS"`), com fallback para o formato sem subsegundos.

### 🟡 BUG-META-03 — `DateFormatter` criado a cada chamada (MENOR — performance)

**[FICHEIRO]** `MetadataExtractor.swift` linha 71
**[ISSUE]** Um novo `DateFormatter` é instanciado em cada chamada a `parseExifDate`. O `DateFormatter` é caro para criar.
**[IMPACTO]** Em bibliotecas com milhares de fotos, pode causar pressão de memória e lentidão.
**[FIX]** Usar um `DateFormatter` estático (`static let`).

---

## PARTE 4 — Test Plan XCTest (MetadataExtractor)

O ficheiro de testes foi criado em:
`Tests/PhotoMoveAppTests/MetadataExtractorTests.swift`

### Cobertura dos testes (16 test cases)

| ID | Grupo | Descrição | Tipo |
|---|---|---|---|
| TC-META-01 | Photo EXIF Date | JPEG com DateTimeOriginal válido → dateTaken correcto | Funcional |
| TC-META-02 | Photo EXIF Date | JPEG sem EXIF → dateTaken nil | Funcional |
| TC-META-03 | Robustez | URL inválida → (nil, nil) sem crash | Negativo |
| TC-META-04 | Robustez | Ficheiro corrompido → (nil, nil) sem crash | Negativo |
| TC-META-05 | Camera Model | TIFF Model com espaços → trimmed correctamente | Funcional |
| TC-META-06 | Camera Model | Sem TIFF Model → nil | Funcional |
| TC-META-07 | Camera Model | Model só com espaços → string vazia | Edge Case |
| TC-META-08 | parseExifDate | Formato standard EXIF → parse correcto | Funcional |
| TC-META-09 | parseExifDate | Subsegundos / timezone / formato inválido → sem crash | Bug Documentation |
| TC-META-10 | parseExifDate | Data de epoch (1970) → sem crash | Edge Case |
| TC-META-11 | parseExifDate | Data futura (2099) → parse correcto | Edge Case |
| TC-META-12 | Video | URL de vídeo inválida → (nil, nil) | Negativo |
| TC-META-13 | Video | Ficheiro .mov real com metadata → integração | Integração |
| TC-META-14 | Concorrência | 50 chamadas paralelas → sem race condition | Thread Safety |
| TC-META-15 | Regressão | Só DateTimeDigitized → nil (documenta bug) | Bug Regression |
| TC-META-16 | Regressão | Só TIFFDateTime → nil (documenta bug) | Bug Regression |

---

## Resumo de Severidade

| Severidade | Count | Bugs |
|---|---|---|
| 🔴 Crítico | 3 | BUG-01, BUG-02, BUG-03 |
| 🟠 Médio | 5 | BUG-04, BUG-05, BUG-06, BUG-META-01, BUG-META-02 |
| 🟡 Menor | 1 | BUG-META-03 |

**Recomendação prioritária**: BUG-01 (integrity check no Move) deve ser corrigido antes de qualquer release, pois envolve perda potencial de dados sem aviso.
