# Variables
ASCIIDOCTOR_REVEALJS = asciidoctor-revealjs
ASCIIDOCTOR         = asciidoctor
SLIDES_DIR          = slides
DIST_DIR            = dist

# Detectar slides .adoc y generar rutas destino
SLIDES       = $(wildcard $(SLIDES_DIR)/*.adoc)
SLIDES_HTML  = $(patsubst $(SLIDES_DIR)/%.adoc,$(DIST_DIR)/slides/%.html,$(SLIDES))

# Compilar todo
all: slides index assets

# Generar slides en HTML
slides: $(SLIDES_HTML)

$(DIST_DIR)/slides/%.html: $(SLIDES_DIR)/%.adoc
	mkdir -p $(DIST_DIR)/slides
	$(ASCIIDOCTOR_REVEALJS) -a revealjs_customcss=custom.css $< -D $(DIST_DIR)/slides


# Generar índice (opcional)
index: index.adoc
	mkdir -p $(DIST_DIR)
	$(ASCIIDOCTOR) index.adoc -D $(DIST_DIR)

# Copiar imágenes y CSS personalizados
assets:
	@if [ -d $(SLIDES_DIR)/private_imgs ]; then \
		cp -r $(SLIDES_DIR)/private_imgs $(DIST_DIR)/slides/; \
	fi
	@if [ -f $(SLIDES_DIR)/custom.css ]; then \
		cp $(SLIDES_DIR)/custom.css $(DIST_DIR)/slides/; \
	fi

# Servidor local
serve: all
	python3 -m http.server --directory $(DIST_DIR) 8080

# Limpiar
clean:
	rm -rf $(DIST_DIR)
