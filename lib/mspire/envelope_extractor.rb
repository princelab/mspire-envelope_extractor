require "mspire/envelope_extractor/version"
require 'mspire/mzml'
require 'mspire/mass/subatomic'
require 'nokogiri'
require 'ostruct'
require 'csv'
#require 'mspire/obo'

module Mspire
  class EnvelopeExtractor
    Peptide = Struct.new(:id, :aaseq, :mods)
    Mod = Struct.new(:m_mass_delta, :location, :residues, :accession, :name)

    SpecIDResult = Struct.new(:id, :spectra_data_ref, :spectrum_id) do
      # returns a non-negative integer.  Expects spectrum_id to be a string
      # "index=<DIGIT(s)>"
      def spectrum_index
        self.spectrum_id[/index=(\d+)/,1].to_i
      end
    end

    IsotopeDistDetail = Struct.new(start_mz, mz_delta, charge) do

      def initialize(spectrum, start_mz, charge, mz_delta=0.01, num=5, mass_of_neutron=Mspire::Mass::Subatomic::MONO[:neutron])
        ints = spectrum.intensities
        (0..(num-1)).map do |n|
          mz = start_mz + (n*mass_of_neutron / charge)
          indices = spectrum.select_indices(mz-mz_delta..mz+mz_delta)
          indices.map {|i| ints[i] }.reduce(:+)
        end
      end
      
    end

    SearchHit = Struct.new(:spec_id_result, :mz_theor, :charge, :mz_exp, :peptide, :score)

    ABSciexInfo = Struct.new(:precursor_elution, :spectrum_info, :time) do
      # returns the info array
      def info_array
        self.spectrum_info.split('.').map(&:to_i)
      end

      def id
        %w(sample period cycle experiment).zip( info_array[1..-1] ).map {|k,v| "#{k}=#{v}" }.join(' ')
      end

      def precursor_spectrum_id
        (%w(sample period cycle).zip( info_array[1...-1] ).map {|k,v| "#{k}=#{v}" } << "experiment=1").join(' ')
      end
    end

    # score is "Conf"
    ABSciexSearchHit = Struct.new(:info, :mz_theor, :charge, :mz_exp, :peptide, :score) do
      def id
        info.id
      end

      # gets the first experiment of that cycle (which for absciex is likely
      # the precursor spectrum)
      def precursor_spectrum_id
        info.precursor_spectrum_id
      end
    end

    CVParam = Struct.new(:accession, :value, :name)

    def initialize(opts={})
      @opt = OpenStruct.new(opts)
    end


    # search_hits_file is an mzidentml file or an absciex peptide summary.
    def extract_from_files(mzml_file, search_hits_file)
      search_hits = search_hits(search_hits_file)
      abort "no search hits! aborting..." unless search_hits.size > 0

      sorted_search_hits = search_hits.sort_by(&:score).reverse

      # currently assumes that the file is the same searched
      # could check this in future
      Mspire::Mzml.open(mzml_file) do |mzml|
        sorted_search_hits.each do |search_hit|
          case search_hit
          when SearchHit
            #p search_hit
            #index = search_hit.spec_id_result.spectrum_index
            #puts "INDEX:"
            #p index
            #spectrum = mzml[index]
            #p spectrum
            #index = spectrum.find_nearest_index(search_hit.mz_exp)
            #p index
            abort 'still need to figure out mapping: not obvious at all!'
          when ABSciexSearchHit
            prec_spectrum = mzml[search_hit.precursor_spectrum_id]
            p prec_spectrum.id
            p prec_spectrum.ms_level
            dist = get_isotope_dist(prec_spectrum, search_hit.mz_exp, search_hit.charge)
            p dist
            abort 'here'
          end
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
      node.xpath('./cvParam').map do |node|
        CVParam.new(node['accession'], node['value'], node['name'])
      end
    end

    def get_score(xml_node, accession, cast)
      cv_params = cv_params_under_node(xml_node)
      cv_params.find {|param| param['accession'] == accession}
        .value
        .send(cast) 
    end

    def search_hits_from_absciex_peptidesummary(file)
      csv = CSV.read(file, headers: true, converters: :numeric, header_converters: :symbol, col_sep: "\t", row_sep: "\r\n" )
      csv.by_row!.map do |row|
        peptide = Peptide.new(nil, *row.values_at(:sequence, :modifications))
        info = ABSciexInfo.new(*row.values_at(:precursorelution, :spectrum, :time))
        ABSciexSearchHit.new(info, *row.values_at(:theor_mz, :theor_z, :prec_mz), peptide, row[:conf])
      end
    end

    def search_hits_from_mzidentml(mzidentml_file)
      search_hits = []
      File.open(mzidentml_file) do |mzidentml_io|
        doc = Nokogiri::XML.parse(mzidentml_io) {|cfg| cfg.noblanks.strict }
        doc.remove_namespaces!
        mzidentml_n = doc.root
        peptides = mzidentml_n.xpath('./SequenceCollection/Peptide').map do |pep_n|
          peptide_from_xml_node(pep_n)
        end
        id_to_peptide = peptides.index_by(&:id)
        mzidentml_n.xpath('./DataCollection/AnalysisData/SpectrumIdentificationList/SpectrumIdentificationResult').map do |result_n|
          ## currently assumes one search hit for each result (can be broken)
          spec_id_result = SpecIDResult.new(result_n['id'], result_n['spectraData_ref'], result_n['spectrumID'])
          hits = result_n.children.map do |spec_id_item_n|
            abort 'expecting different node' unless spec_id_item_n.name == 'SpectrumIdentificationItem'
            # calculatedMassToCharge="603.30634" chargeState="3" experimentalMassToCharge="603.2957" id="SII_35_2" passThreshold="true" rank="1" peptide_ref="PEPTIDE_2"
            hit = SearchHit.new(spec_id_result, spec_id_item_n['calculatedMassToCharge'], spec_id_item_n['chargeState'], spec_id_item_n['experimentalMassToCharge'], id_to_peptide[spec_id_item_n['peptide_ref']])

            hit.score = get_score(spec_id_item_n, 'MS:1001950', :to_f) # PEAKS:peptideScore
            hit
          end
          warn "multiple hits (likely isomers)" if hits.size > 1
          search_hit = hits.first
          search_hit.spec_id_result = spec_id_result
          search_hit
        end
      end
    end

    # this is very narrowly defined: must have the exact same first line
    # (headers) as the only file I've seen in this format.
    def is_absciex_summary_file?(file)
      data = IO.read(file, 227)
      first_line = "N\tUnused\tTotal\t%Cov\t%Cov(50)\t%Cov(95)\tAccessions\tNames\tUsed\tAnnotation\tContrib\tConf\tSequence\tModifications\tCleavages\tdMass\tPrec MW\tPrec m/z\tTheor MW\tTheor m/z\tTheor z\tSc\tSpectrum\tSpecific\tTime\tPrecursorSignal\tPrecursorElution\r\n"
      if first_line =~ /N\tUnused\tTotal/
        warn "absciex file but not expected headers! (may corrupt everything downstream)" unless first_line == data 
        true
      else
        false
      end
    end

    # retrieve the search hits from the mzidentml file
    def search_hits(file)
      if is_absciex_summary_file?(file)
        search_hits_from_absciex_peptidesummary(file)
      else
        search_hits_from_mzidentml(file)
      end
    end
  end
end
