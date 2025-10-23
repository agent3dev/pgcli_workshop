# ER Diagrams

This folder contains scripts and files for generating entity-relationship diagrams of the workshop schemas.

## Files

- `generate_er.py`: Python script that parses SQL schema files and generates Graphviz DOT files
- `bad_schema.dot`: ER diagram for the denormalized schema (includes all tables from bad schema)
- `normalized_schema.dot`: ER diagram for the normalized schema (3NF with relationships)
- `*.png`: Generated PNG images (run `dot -Tpng *.dot -o *.png` if Graphviz installed)

## Usage

### Generate Diagrams
```bash
cd diagrams
python generate_er.py
```

This will:
1. Parse `../sql/01_bad_schema.sql` and `../sql/02_normalized_schema.sql`
2. Generate `bad_schema.dot` and `normalized_schema.dot`
3. Generate PNG images using Graphviz (if installed)

### Manual Generation
If you modify the DOT files:
```bash
# Generate PNG
dot -Tpng bad_schema.dot -o bad_schema.png
dot -Tpng normalized_schema.dot -o normalized_schema.png

# Generate PDF
dot -Tpdf bad_schema.dot -o bad_schema.pdf
dot -Tpdf normalized_schema.dot -o normalized_schema.pdf
```

## How It Works

The `generate_er.py` script:

1. **Parses SQL**: Extracts table definitions from CREATE TABLE statements
2. **Identifies Relationships**: Finds foreign key constraints
3. **Generates DOT**: Creates Graphviz DOT language files with:
   - Table nodes with columns
   - Relationship edges between tables
   - Primary keys in **bold**
   - Foreign keys in *italics*

## Example Output

### Bad Schema (Denormalized)
```
pedidos_completos
├── cliente_nombre
├── cliente_email
├── producto1_nombre
├── producto1_precio
├── ...
└── fecha_pedido
```

### Normalized Schema (3NF)
```
clientes ─── pedidos ─── items_pedido ─── productos ─── categorias
    └── direcciones
```

## Requirements

- Python 3
- Graphviz (optional, for PNG generation)
  ```bash
  sudo apt install graphviz  # Ubuntu/Debian
  brew install graphviz      # macOS
  ```

## Integration

Add to workshop `Makefile`:
```makefile
diagrams:
    cd diagrams && python generate_er.py
    dot -Tpng diagrams/*.dot -o diagrams/*.png
```</content>
</xai:function_call