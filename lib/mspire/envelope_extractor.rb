require "mspire/envelope_extractor/version"
require 'mspire/mzml'
require 'nokogiri'
require 'ostruct'

module Mspire
  class EnvelopeExtractor
    SearchHit = Struct.new(:mz_theor, :mz_exp, :peptide, :mods, :score)

    def initialize(opts={})
      @opt = OpenStruct.new(opts)
    end

    def extract_from_files(mzml_file, mzidentml_file)
      search_hits(mzidentml_file)
    end

    # retrieve the search hits from the mzidentml file
    def search_hits(mzidentml_file)
      search_hits = []
      id_to_peptide = {}
      File.open(mzidentml_file) do |mzidentml_io|
        doc = Nokogiri::XML.parse(mzidentml_io) {|cfg| cfg.noblanks.strict }
        doc.remove_namespaces!
        mzidentml_n = doc.root
        mzidentml_n.xpath('./SequenceCollection/Peptide').each do |pep_n|
          p pep_n['id']
          seq_n = pep_n.child
          p seq_n.text
          seq_n.next

        end
      end
    end
  end
end
