# === Variables ===
ASCIIDOCTOR_REVEALJS = asciidoctor-revealjs
ASCIIDOCTOR          = asciidoctor
SLIDES_DIR           = slides
DIST_DIR             = dist
DECKTAPE             = npx decktape   # usa 'npx decktape' o 'decktape' si lo tienes global

# Detectar slides .adoc y generar rutas destino
SLIDES        = $(wildcard $(SLIDES_DIR)/*.adoc)
SLIDES_HTML   = $(patsubst $(SLIDES_DIR)/%.adoc,$(DIST_DIR)/slides/%.html,$(SLIDES))
SLIDES_PDF    = $(patsubst $(SLIDES_DIR)/%.adoc,$(DIST_DIR)/slides/%.pdf,$(SLIDES))

# === Targets principales ===
all: slides index assets

pdf: $(SLIDES_PDF)

# === Generar slides en HTML ===
slides: $(SLIDES_HTML)

$(DIST_DIR)/slides/%.html: $(SLIDES_DIR)/%.adoc
	mkdir -p $(DIST_DIR)/slides
	$(ASCIIDOCTOR_REVEALJS) -r asciidoctor-kroki $< -D $(DIST_DIR)/slides

# === Generar PDFs con Decktape ===
$(DIST_DIR)/slides/%.pdf: $(DIST_DIR)/slides/%.html
	@echo "→ Generando PDF para $< ..."
	$(DECKTAPE) reveal file://$(abspath $<)?print-pdf $@

# === Generar índice (opcional) ===
index: index.adoc
	mkdir -p $(DIST_DIR)
	$(ASCIIDOCTOR) index.adoc -D $(DIST_DIR)

# === Copiar imágenes y CSS personalizados ===
assets:
	@if [ -d $(SLIDES_DIR)/private_imgs ]; then \
		cp -r $(SLIDES_DIR)/private_imgs $(DIST_DIR)/slides/; \
	fi
	@if [ -f $(SLIDES_DIR)/custom.css ]; then \
		cp $(SLIDES_DIR)/custom.css $(DIST_DIR)/slides/; \
	fi

# === Servidor local ===
serve: all
	python3 -m http.server  --bind localhost --directory $(DIST_DIR) 8080

# === Limpieza ===
clean:
	rm -rf $(DIST_DIR)
