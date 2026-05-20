require "zip"

module FotosMelon
  # Construye un ZIP en streaming. La clave para que no se infle la RAM
  # es nunca cargar el archivo entero en memoria: usamos `download_chunk`
  # de ActiveStorage::Blob, escribiéndolo por bloques en el writer del zip,
  # y a su vez el zip se va escribiendo en la respuesta HTTP a medida que se genera.
  #
  # Detalles importantes:
  # - Usamos rubyzip con ZipOutputStream apuntado a un IO que es el response.stream.
  # - Cada blob se itera con `blob.open` (que internamente usa stream/Tempfile chico)
  #   o con `blob.download { |chunk| ... }` (mejor: no necesita Tempfile completo).
  # - Forzamos GC.start cada N archivos para soltar memoria si quedó pegada.
  class ZipStreamer
    CHUNK = 64 * 1024  # 64KB

    # entries: array de hashes con { nombre_en_zip:, blob: ActiveStorage::Blob }
    # io: IO escribible (típicamente response.stream)
    def self.stream(entries, io)
      writer = ::Zip::OutputStream.write_buffer(io, encrypter = nil) do |zip|
        entries.each_with_index do |entry, idx|
          blob = entry[:blob]
          next unless blob

          nombre = entry[:nombre_en_zip].to_s
          zip.put_next_entry(nombre, nil, nil, ::Zip::Entry::DEFLATED, ::Zlib::DEFAULT_COMPRESSION)

          # Escribimos el blob por chunks; nunca cargamos el archivo completo en RAM.
          blob.download do |chunk|
            zip.write(chunk)
          end

          # Cada 10 archivos pedimos GC para evitar acumulación.
          GC.start if (idx % 10).zero? && idx.positive?
        end
      end
      writer.close
    rescue IOError, Errno::EPIPE
      # El cliente cortó la descarga; no hacemos drama.
      nil
    end

    # Versión simple usando ZipOutputStream directamente sobre un IO escribible.
    # rubyzip no expone ZipOutputStream(io) público de forma estable en todas las versiones,
    # así que ofrecemos una alternativa con monkey-friendly: escribir a un IO custom.
    def self.stream_to_io(entries, io)
      ::Zip.default_compression = ::Zlib::DEFAULT_COMPRESSION
      sink = StreamSink.new(io)
      zip = ::Zip::OutputStream.new(sink, true)
      begin
        entries.each_with_index do |entry, idx|
          blob = entry[:blob]
          next unless blob
          nombre = entry[:nombre_en_zip].to_s
          zip.put_next_entry(nombre)
          blob.download do |chunk|
            zip.write(chunk)
          end
          GC.start if (idx % 10).zero? && idx.positive?
        end
      ensure
        zip.close
      end
    rescue IOError, Errno::EPIPE
      nil
    end

    # IO mínimo que rubyzip puede usar como sink y que delega en response.stream.
    # rubyzip llama a #write y #tell; emulamos tell con un contador.
    class StreamSink
      def initialize(out)
        @out = out
        @pos = 0
      end

      def write(data)
        bytes = data.bytesize
        @out.write(data)
        @pos += bytes
        bytes
      end

      def tell
        @pos
      end

      def pos
        @pos
      end

      def flush
        @out.flush if @out.respond_to?(:flush)
      end

      def close
        # No cerramos el response.stream aquí; el controller lo hace.
        nil
      end
    end
  end
end
