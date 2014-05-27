require 'optparse'
require 'ostruct'

module Mspire
  class EnvelopeExtractor
    module Commandline
      def self.run(progname, argv)

        opt = OpenStruct.new({})
        parser = OptionParser.new do |op|
          op.banner = "usage: #{progname} <mzmlfile>.mzML <mzidentmlfile>.mzid"
          op.separator "output: <mzidentmlfile>.csv"
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
