# app/scripts/generate_excel.py
#!/usr/bin/env python3
import sys, json
import openpyxl

def main():
    if len(sys.argv) < 3:
        print("Usage: generate_excel.py <facturaciones_json> <output_file>")
        sys.exit(1)

    facturaciones = json.loads(sys.argv[1])
    output_file    = sys.argv[2]

    wb = openpyxl.Workbook()
    ws = wb.active
    ws.title = "Facturaciones"

    #headers
    headers = [
      "N° Corr",
      "Nombre",
      "Fecha Inspección",
      "Inspecciones Completadas",
      "Fecha Entrega Informes",
      "Fecha Factura",
      "Ubicación",
      "Empresa",
      "Precio UF",
      "Precio Pesos"
    ]
    ws.append(headers)

    #filas
    for f in facturaciones:
        row = [
            f.get("number"),
            f.get("name"),
            f.get("fecha_inspeccion"),
            f.get("inspecciones_completadas"),
            f.get("fecha_entrega"),
            f.get("factura"),
            f.get("ubicacion"),
            f.get("empresa"),
            f.get("precio"),
            f.get("pesos")
        ]
        ws.append(row)


    ws.auto_filter.ref = ws.dimensions

    ws.freeze_panes = "A2"

    wb.save(output_file)
    print(f"Archivo Excel generado en: {output_file}")

if __name__ == "__main__":
    main()
