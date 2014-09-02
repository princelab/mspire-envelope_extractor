#!/usr/bin/env ruby

require 'gnuplot'
require 'mspire/molecular_formula'
require 'mspire/isotope/distribution'

if ARGV.size < 4
  puts "usage: #{File.basename(__FILE__)} <AASEQ> charge mz,mz,... int,int,... [mz,mz...:int,int... ...]" 
  exit
end

(aaseq, charge_st, mzs_st, ints_st, *fine_isotope_strings) = ARGV

charge = charge_st.to_i
cent_mzs = mzs_st.split(',').map(&:to_f)
cent_ints = ints_st.split(',').map(&:to_f)

fine_isotopes = fine_isotope_strings.each_with_index.map do |fine_isotope_string,i|
  (mzs, ints) = fine_isotope_string.split(':').map {|st| st.split(',').map(&:to_f) }
  [mzs, ints]
end
p fine_isotopes
max_int = fine_isotopes.map(&:last).flatten(1).max


max_cent_int = cent_ints.max
cent_ints.map! {|v| (v / max_cent_int) * max_int }

mf = Mspire::MolecularFormula.from_aaseq(aaseq) + Mspire::MolecularFormula["H#{charge}"]
puts mf.to_s
mf.charge = charge

puts mf.mass / mf.charge
spectrum = mf.isotope_distribution_spectrum(normalize: :max, peak_cutoff: 5)
spectrum.intensities.map! {|int| int * max_int }

Gnuplot.open do |gp|
  Gnuplot::Plot.new(gp) do |plot|
    plot.title "#{aaseq}:#{charge}"
    plot.data << Gnuplot::DataSet.new( [spectrum.mzs, spectrum.intensities] ) do |ds|
      ds.title = "theoretical"
      ds.with = "boxes"
    end

    plot.data << Gnuplot::DataSet.new( [cent_mzs, cent_ints] ) do |ds|
      ds.title = "actual"
      ds.with = "impulses"
    end

    fine_isotope_strings.each_with_index do |fine_isotope_string,i|
      (mzs, ints) = fine_isotope_string.split(':').map {|st| st.split(',').map(&:to_f) }
      plot.data << Gnuplot::DataSet.new( [mzs, ints] ) do |ds|
        ds.title = "m#{i}"
        ds.with = "lines"
      end

    end

  end
end






