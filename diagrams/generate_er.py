#!/usr/bin/env python3
"""
Generate ER Diagrams from SQL schemas using Graphviz
Usage: python generate_er.py
"""

import re
import os
from pathlib import Path

class ERDiagramGenerator:
    def __init__(self):
        self.tables = {}
        self.relationships = []

    def parse_create_table(self, sql_content):
        """Parse CREATE TABLE statements from SQL"""
        # Find all CREATE TABLE statements
        table_pattern = r'CREATE TABLE (\w+)\s*\((.*?)\);'
        matches = re.findall(table_pattern, sql_content, re.DOTALL | re.IGNORECASE)

        for table_name, columns_sql in matches:
            columns = []
            foreign_keys = []

            # Parse columns
            column_lines = [line.strip() for line in columns_sql.split('\n') if line.strip() and not line.strip().startswith('--')]

            for line in column_lines:
                line = line.rstrip(',')
                if not line:
                    continue

                # Check for foreign key references
                fk_match = re.search(r'REFERENCES (\w+)\((\w+)\)', line, re.IGNORECASE)
                if fk_match:
                    ref_table, ref_column = fk_match.groups()
                    # Extract column name
                    col_match = re.match(r'(\w+)\s+.*REFERENCES', line, re.IGNORECASE)
                    if col_match:
                        col_name = col_match.group(1)
                        foreign_keys.append((col_name, ref_table, ref_column))

                # Add column to list
                columns.append(line)

            self.tables[table_name] = {
                'columns': columns,
                'foreign_keys': foreign_keys
            }

    def generate_relationships(self):
        """Generate relationships from foreign keys"""
        self.relationships = []
        for table_name, table_info in self.tables.items():
            for fk_col, ref_table, ref_col in table_info['foreign_keys']:
                # Determine relationship type (simplified)
                # In workshop: clientes -> pedidos (1:N), etc.
                if ref_table in self.tables:
                    self.relationships.append((ref_table, table_name, f"{fk_col}->{ref_col}"))

    def generate_dot(self, title="ER Diagram"):
        """Generate DOT language string with HTML labels"""
        dot = [f'digraph "{title}" {{',
               '    rankdir=LR;',
               '    node [shape=plaintext, fontsize=10];',
               '    edge [fontsize=8];']

        # Add nodes (tables) with HTML table labels
        for table_name, table_info in self.tables.items():
            # Build HTML table
            html = [f'<table border="1" cellborder="0" cellspacing="0">',
                    f'<tr><td bgcolor="lightblue"><b>{table_name}</b></td></tr>']

            for col in table_info['columns'][:10]:  # Limit columns for readability
                # Escape HTML entities
                col_escaped = (col.replace('&', '&amp;')
                              .replace('<', '&lt;')
                              .replace('>', '&gt;')
                              .replace('"', '&quot;'))
                # Mark PK and FK
                if '(pk)' in col.lower() or 'primary key' in col.lower():
                    html.append(f'<tr><td align="left"><b>{col_escaped}</b></td></tr>')
                elif any(fk[0] in col for fk in table_info['foreign_keys']):
                    html.append(f'<tr><td align="left"><i>{col_escaped}</i></td></tr>')
                else:
                    html.append(f'<tr><td align="left">{col_escaped}</td></tr>')

            if len(table_info['columns']) > 10:
                html.append('<tr><td align="left">...</td></tr>')

            html.append('</table>')

            label = '<' + ''.join(html) + '>'
            dot.append(f'    {table_name} [label={label}];')

        # Add edges (relationships)
        for from_table, to_table, label in self.relationships:
            dot.append(f'    {from_table} -> {to_table} [label="{label}"];')

        dot.append('}')
        return '\n'.join(dot)

def main():
    """Generate ER diagrams for workshop schemas"""
    workshop_dir = Path(__file__).parent.parent
    diagrams_dir = workshop_dir / 'diagrams'
    sql_dir = workshop_dir / 'sql'

    # Generate bad schema diagram
    bad_sql_file = sql_dir / '01_bad_schema.sql'
    if bad_sql_file.exists():
        print("Generating bad schema ER diagram...")
        generator = ERDiagramGenerator()

        with open(bad_sql_file, 'r') as f:
            generator.parse_create_table(f.read())

        generator.generate_relationships()
        dot_content = generator.generate_dot("Bad Schema (Denormalized)")

        with open(diagrams_dir / 'bad_schema.dot', 'w') as f:
            f.write(dot_content)

        print(f"Created: {diagrams_dir / 'bad_schema.dot'}")

    # Generate normalized schema diagram
    normalized_sql_file = sql_dir / '02_normalized_schema.sql'
    if normalized_sql_file.exists():
        print("Generating normalized schema ER diagram...")
        generator = ERDiagramGenerator()

        with open(normalized_sql_file, 'r') as f:
            generator.parse_create_table(f.read())

        generator.generate_relationships()
        dot_content = generator.generate_dot("Normalized Schema (3NF)")

        with open(diagrams_dir / 'normalized_schema.dot', 'w') as f:
            f.write(dot_content)

        print(f"Created: {diagrams_dir / 'normalized_schema.dot'}")

    # Generate images using dot (if available)
    try:
        import subprocess
        print("Generating PNG images...")

        for dot_file in ['bad_schema.dot', 'normalized_schema.dot']:
            dot_path = diagrams_dir / dot_file
            png_path = diagrams_dir / dot_file.replace('.dot', '.png')

            if dot_path.exists():
                subprocess.run(['dot', '-Tpng', str(dot_path), '-o', str(png_path)],
                             check=True, capture_output=True)
                print(f"Created: {png_path}")

    except (subprocess.CalledProcessError, FileNotFoundError):
        print("Graphviz 'dot' command not found. Install graphviz to generate PNG images.")
        print("You can generate manually: dot -Tpng file.dot -o file.png")

    print("\nER diagrams generated successfully!")
    print("Use: dot -Tpng diagrams/*.dot -o diagrams/*.png")

if __name__ == "__main__":
    main()