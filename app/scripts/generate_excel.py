#!/usr/bin/env python
import sys
import json
import openpyxl

def main():
    # sys.argv[0] = "generate_excel.py"
    # sys.argv[1] = JSON con facturaciones
    # sys.argv[2] = ruta de salida
    if len(sys.argv) < 3:
        print("Usage: generate_excel.py <facturaciones_json> <output_file>")
        sys.exit(1)

    facturaciones_json = sys.argv[1]
    output_file = sys.argv[2]

    facturaciones = json.loads(facturaciones_json)

    wb = openpyxl.Workbook()
    ws = wb.active
    ws.title = "Facturaciones"

    headers = ["ID", "Number", "Name", "Empresa", "Fecha Inspección", "Factura", "Precio"]
    ws.append(headers)

    for f in facturaciones:
        row = [
            f.get("id"),
            f.get("number"),
            f.get("name"),
            f.get("empresa"),
            f.get("fecha_inspeccion"),
            f.get("factura"),
            f.get("precio")
        ]
        ws.append(row)

    wb.save(output_file)
    print(f"Archivo Excel generado en: {output_file}")

if __name__ == "__main__":
    main()
