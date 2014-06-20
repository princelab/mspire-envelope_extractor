require "mspire/envelope_extractor/version"
require 'mspire/mzml'
require 'nokogiri'
require 'ostruct'
#require 'mspire/obo'



module Mspire
  class EnvelopeExtractor
    Peptide = Struct.new(:id, :aaseq, :mods)
    Mod = Struct.new(:m_mass_delta, :location, :residues, :accession, :name)

    SpecIDResult.new(:id, :spectra_data_ref, :spectrum_id)
    SearchHit = Struct.new(:spec_id_result, :mz_theor, :charge, :mz_exp, :peptide, :score)

    CVParam = Struct.new(:accession, :value, :name)

    def initialize(opts={})
      @opt = OpenStruct.new(opts)
    end

    def extract_from_files(mzml_file, mzidentml_file)
      search_hits = search_hits(mzidentml_file)
      # currently assumes that the file is the same searched
      # could check this in future
      Mspire::Mzml.open(mzidentml_file) do |mzml|
        search_hits.each do |search_hit|
          spectrum = mzml[search_hit.spec_id_result.spectrum_id]
          spectrum.find_nearest_mz_index(
        end
      end

    end

    def peptide_from_xml_node(peptide_node)
      seq_n = peptide_node.child
      peptide = Peptide.new(peptide_node['id'], seq_n.text)
      mods = peptide_node.xpath('./Modification').map do |mod_n|
        #monoisotopicMassDelta="57.021465" location="5" residues="C
        mod = Mod.new(mod_n['monoisotopicMassDelta'], mod_n['location'], mod_n['residues'])
        param_n = mod_n.child
        mod.accession = param_n['accession']
        mod.name = param_n['name']
        mod
      end
      peptide.mods = mods
      peptide
    end

    def cv_params_under_node(node)
      node.xpath('./CVParam').map do |node|
        CVParam.new(node['accession'], node['value'], node['name'])
      end
    end

    def get_score(xml_node, accession, cast)
      cv_params = cv_params_under_node(xml_node)
      cv_params.find {|param| param['accession'] == accession}
        .value
        .send(cast) 
    end

    # retrieve the search hits from the mzidentml file
    def search_hits(mzidentml_file)
      search_hits = []
      File.open(mzidentml_file) do |mzidentml_io|
        doc = Nokogiri::XML.parse(mzidentml_io) {|cfg| cfg.noblanks.strict }
        doc.remove_namespaces!
        mzidentml_n = doc.root
        peptides = mzidentml_n.xpath('./SequenceCollection/Peptide').map do |pep_n|
          peptide_from_xml_node(pep_n)
        end
        id_to_peptide = peptides.index_by(&:id)
        mzidentml_n.xpath('./SpectrumIdentificationResult').map do |result_n|
          ## currently assumes one search hit for each result (can be broken)
          spec_id_result = SpecIDResult.new(result_n['id'], result_n['spectrumID'], result_n['spectraData_ref'])
          hits = result_n.children.map do |spec_id_item_n|
            abort 'expecting different node' unless spec_id_item_n.name == 'SpectrumIdentificationItem'
            # calculatedMassToCharge="603.30634" chargeState="3" experimentalMassToCharge="603.2957" id="SII_35_2" passThreshold="true" rank="1" peptide_ref="PEPTIDE_2"
            hit = SearchHit.new(spec_id_result, spec_id_item_n['calculatedMassToCharge'], spec_id_item_n['chargeState'], spec_id_item_n['experimentalMassToCharge'], id_to_peptide[spec_id_item_n['peptide_ref']])

            hit.score = get_score(spec_id_item_n, 'MS:1001950', :to_f) # PEAKS:peptideScore
            hit
          end
          abort "expecting only 1 hit" if hits.size > 1 
          search_hit = hits.first
          search_hit.spec_id_result = spec_id_result
          search_hit
        end
      end
    end
  end
end
