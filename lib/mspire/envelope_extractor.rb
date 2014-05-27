require "mspire/envelope_extractor/version"
require 'mspire/mzml'
require 'nokogiri'

module Mspire
  class EnvelopeExtractor
  end
end



module Mspire
  class EnvelopeExtractor
    def initialize(opts={})
    end

    def extract_from_files(mzml_file, mzidentml_file)
      def search_hits(mzidentml_file)
        File.open(mzidentml_file) do |mzidentml_io|
          Nokogiri::XML::Reader(
        end
      end
    end
  end
end
