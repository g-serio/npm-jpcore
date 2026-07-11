#!/bin/bash

# Nome dello script finale che verrà generato
OUTPUT="install_npm.jpcore.sh"
# Delimitatore per l'HEREDOC
DELIMITER="END_OF_FILE_CONTENT"

# 0. Controllo argomenti (Governance)
if [ $# -eq 0 ]; then
    echo "❌ Errore: Devi specificare almeno una cartella o un file."
    echo "Esempio: bash code2text.sh src"
    echo "Esempio: bash code2text.sh src lib/schemas.ts"
    exit 1
fi

echo "🔍 Analisi dei target: $@..."
echo "Generazione dello script $OUTPUT in corso..."

# 1. Crea l'intestazione dello script finale
cat > "$OUTPUT" << HEADER
#!/bin/bash
set -e # Termina se c'è un errore

echo "Inizio ricostruzione progetto..."

HEADER

# 2. Esegui il find solo sui target indicati ($@)
# Escludiamo file nascosti e lo script stesso
find "$@" -not -path '*/.*' -not -name "$OUTPUT" -not -name "$(basename "$0")" | sort | while read -r FILE; do
    
    # Rimuovi il "./" iniziale se presente per pulizia
    CLEAN_PATH="${FILE#./}"

    if [ -d "$FILE" ]; then
        # SE È UNA CARTELLA: Scrivi il comando mkdir
        echo "mkdir -p \"$CLEAN_PATH\"" >> "$OUTPUT"
    
    elif [ -f "$FILE" ]; then
        # SE È UN FILE:
        # Controllo se è un file binario
        if grep -qI . "$FILE"; then
            # È un file di testo
            echo "echo \"Creating $CLEAN_PATH...\"" >> "$OUTPUT"
            
            # Scrive l'intestazione del cat
            echo "cat << '$DELIMITER' > \"$CLEAN_PATH\"" >> "$OUTPUT"
            
            # Copia il contenuto del file
            cat "$FILE" >> "$OUTPUT"
            
            # Assicura che ci sia un ritorno a capo prima del delimitatore
            echo "" >> "$OUTPUT"
            
            # Chiude il blocco dati
            echo "$DELIMITER" >> "$OUTPUT"

            # Se il file originale era eseguibile, ripristina i permessi
            if [ -x "$FILE" ]; then
                echo "chmod +x \"$CLEAN_PATH\"" >> "$OUTPUT"
            fi
        else
            echo "# SKIP: $CLEAN_PATH è un file binario e non può essere convertito in testo." >> "$OUTPUT"
            echo "Attenzione: $CLEAN_PATH ignorato (binario)."
        fi
    fi
done

# 3. Rende lo script generato eseguibile
chmod +x "$OUTPUT"

echo "✅ Fatto! Generato $OUTPUT basato sui target: $@"
echo "Esegui ./$OUTPUT per ricreare la struttura."