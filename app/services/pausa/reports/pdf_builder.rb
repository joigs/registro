# app/services/pausa/reports/pdf_builder.rb
# frozen_string_literal: true
require "prawn"
require "prawn/table"
require "set"

module Pausa
  module Reports
    class PdfBuilder
      Cell = Struct.new(:morning_done, :evening_done, :estado_false)

      def self.build(start_date:, end_date:, logs:, users:, windows:, holidays: nil)
        holidays_set =
          case holidays
          when Set   then holidays
          when Array then holidays.to_set
          else Set.new
          end

        today = Time.zone ? Time.zone.today : Date.today

        # Solo L–V
        all_days = (start_date..end_date).select { |d| (1..5).include?(d.wday) }
        # Agrupar por lunes de la semana
        weeks = all_days.group_by { |d| monday_of(d) }.sort_by { |monday, _| monday }

        # Indexar logs por (user_id, fecha)
        by_key = logs.group_by { |l| [l.app_user_id, l.fecha] }

        Prawn::Document.new(page_size: "A4", margin: 24) do |pdf|
          pdf.font_size 10
          pdf.text "Reporte Pausas Activas", size: 16, style: :bold, align: :center
          pdf.move_down 6
          pdf.text "Rango: #{fmt_dmy(start_date)} – #{fmt_dmy(end_date)}", align: :center
          pdf.move_down 4
          pdf.text "Horario: Mañana #{fmt_hhmm(windows[:morning])} / Tarde #{fmt_hhmm(windows[:evening])}", align: :center
          pdf.move_down 10

          weeks.each_with_index do |(monday, _), idx|
            # Asegurar L–V dentro del rango
            days = (0..4).map { |i| monday + i }.select { |d| d >= start_date && d <= end_date }

            pdf.start_new_page if idx.positive?
            pdf.text "Semana del #{fmt_dmy(days.first)} al #{fmt_dmy(days.last)}",
                     size: 12, style: :bold, align: :left
            pdf.move_down 6

            # Cabecera (usar <s>...</s> para tachado compatible con Prawn)
            header = %w[Nombre RUT Horario] + days.map { |d|
              txt = fmt_dm(d)
              holidays_set.include?(d) ? "<s>#{txt}</s>" : txt
            }

            # Construir grilla de celdas
            grid = Hash.new { |h, k| h[k] = {} }
            users.each do |u|
              days.each do |d|
                l = by_key[[u.id, d]]&.first
                grid[u.id][d] = Cell.new(l&.morning_done, l&.evening_done, (u.estado == false))
              end
            end

            rows = []
            users.each do |u|
              # Unir "Nombre" y "RUT" en dos filas (rowspan: 2)
              name_cell = pdf.make_cell(content: u.nombre, rowspan: 2)
              rut_cell  = pdf.make_cell(content: u.rut,    rowspan: 2)

              row_m = [name_cell, rut_cell, "Mañana"]
              row_e = ["Tarde"]  # por el rowspan, no se agregan placeholders

              days.each do |d|
                if holidays_set.include?(d)
                  # Feriado: prioridad máxima → N/A
                  row_m << "N/A"
                  row_e << "N/A"
                else
                  future = d > today
                  c = grid[u.id][d]

                  if c&.estado_false
                    # Usuario desactivado: guion
                    row_m << "—"
                    row_e << "—"
                  else
                    # Futuro: deja en blanco (espacios) como ya tenías
                    row_m << (future ? "    " : (c&.morning_done ? "Sí" : "No"))
                    row_e << (future ? "    " : (c&.evening_done ? "Sí" : "No"))
                  end
                end
              end

              rows << row_m
              rows << row_e
            end

            pdf.table([header] + rows, header: true, cell_style: { size: 9, inline_format: true }) do |t|
              t.row(0).font_style       = :bold
              t.row(0).background_color = "F0F0F0"
              t.cells.border_width      = 0.5
              t.columns(0).width = 150  # Nombre
              t.columns(1).width = 70   # RUT
              t.columns(2).width = 50   # Horario
            end
          end

          pdf.number_pages "<page>/<total>", at: [pdf.bounds.right - 40, 0], size: 9
        end.render
      end

      # Helpers
      def self.monday_of(date) = date - (date.cwday - 1) # 1=Lunes..7=Domingo
      def self.fmt_dmy(d) = d.strftime("%d-%m-%Y")
      def self.fmt_dm(d)  = d.strftime("%d-%m")
      def self.fmt_hhmm(hm) = "%02d:%02d" % [hm[:h], hm[:m]]
    end
  end
end
