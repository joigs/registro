#!/usr/bin/env python3
import sys, json
import openpyxl

def main():
    if len(sys.argv) < 3:
        print("Usage: generate_evaluacions_excel.py <data_json> <output_file>")
        sys.exit(1)

    records     = json.loads(sys.argv[1])
    output_file = sys.argv[2]

    wb = openpyxl.Workbook()
    ws = wb.active
    ws.title = "Evaluaciónes"

    #headers
    headers = [
      "N° Corr",
      "Nombre",
      "Solicitud",
      "Emisión",
      "Entregado",
      "Resultado",
      "Orden de Compra",
      "Factura",
      "Fecha Evaluación",
      "Precio UF",
      "Precio Pesos"
    ]
    ws.append(headers)

    # Filas
    for f in records:
        ws.append([
            f.get("number"),
            f.get("name"),
            f.get("solicitud"),
            f.get("emicion"),
            f.get("entregado"),
            f.get("resultado"),
            f.get("oc"),
            f.get("factura"),
            f.get("fecha_inspeccion"),
            f.get("precio"),
            f.get("pesos")
        ])

    ws.auto_filter.ref   = ws.dimensions
    ws.freeze_panes      = "A2"

    wb.save(output_file)
    print(f"Excel generado en: {output_file}")

if __name__ == "__main__":
    main()
