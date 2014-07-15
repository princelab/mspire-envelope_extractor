require 'optparse'
require 'ostruct'
require 'mspire/envelope_extractor'

module Mspire
  class EnvelopeExtractor
    module Commandline
      def self.run(progname, argv)

        opt = OpenStruct.new({})
        parser = OptionParser.new do |op|
          op.banner = "usage: #{progname} <mzmlfile>.mzML <search_hits_file> [<mzmlfile_enriched>.mzML ...]"
          op.separator "[still working on output]"
        end

        if argv.size < 2
          puts parser
          return
        end

        extractor = Mspire::EnvelopeExtractor.new(opt.to_h)
        extractor.extract_from_files(*argv)
      end
    end
  end
end
