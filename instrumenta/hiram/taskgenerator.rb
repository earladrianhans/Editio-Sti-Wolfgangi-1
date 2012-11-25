# There was utils_rake.rb with functions making use of many constants
# locating important files.
# I refactored them in a class that finds the paths.

require 'pathname'

class Hiram::TaskGenerator

  include Rake::DSL

  RUBY_COMMAND = 'ruby'

  def initialize
    here = Pathname.new Dir.pwd

    @instrumenta_dir = Pathname.new(__FILE__).dirname.dirname
    @editio_dir = @instrumenta_dir.dirname

    @instrumenta_dir = @instrumenta_dir.relative_path_from(here).to_s+'/'
    @editio_dir = @editio_dir.relative_path_from(here).to_s+'/'

    # puts @instrumenta_dir, @editio_dir

    @psalm_preprocessor = @instrumenta_dir+'psalmpreprocessor.rb'
    @psalmtones_dir = @editio_dir+'tonipsalmorum/arom12/'
    @psalms_dir = @editio_dir+'psalmi/'
    @czech_psalms_dir = @editio_dir+'bohemice_psalmi/'

    gloriapatri = File.readlines(@psalms_dir + 'gloriapatri.pslm').join ""

    @default_psalm_options = "--accents-style bold "+
      "--append \"#{gloriapatri}\" "+
      "--skip-verses 1 "
    @output_dir = './temporalia/'
  end

  attr_accessor :default_psalm_options
  attr_accessor :output_dir

  # General function generating a Rake task to point a psalm text
  def genpsalm_universal(zalm, options, output_dir, input_dir)
    wd = Dir.pwd
    syrovy = input_dir+"/"+zalm
    peceny = output_dir+zalm.gsub(/\.pslm/, '')+'.tex'
    file peceny => [syrovy, @psalm_preprocessor] do
      chdir output_dir
      sh "#{RUBY_COMMAND} ../#{@psalm_preprocessor} #{options} ../#{syrovy}"
      chdir wd
    end
    return peceny
  end

  # Rake task to point a psalm text
  def genpsalm(zalm, options=@default_psalm_options)
    genpsalm_universal(zalm, options, @output_dir, @psalms_dir)
  end

  # translations not intended to be sung: no pointing at all, no title, ...
  @@czech_psalm_options = "--accents 0:0 --title-pattern \" \" --no-paragraph "

  # Rake task to process a Czech psalm translation
  def genczechpsalm(zalm)
    # find in which set translation of this psalm is
    input_dir = ['Hejcl1922', 'DMC199x', 'Pavlik'].find do|d|
      File.exists? @czech_psalms_dir+'/'+d+'/'+zalm
    end
    
    if input_dir then
      input_dir = @czech_psalms_dir+'/'+input_dir+'/'
    else
      raise "Czech translation of the psalm '#{zalm}' not found."
    end

    of = zalm.gsub(".pslm", "-boh.tex")
    ofop = "--output "+of+" "
    syrovy = input_dir+zalm
    of_fullpath = @output_dir+of
    file of_fullpath => [syrovy, @psalm_preprocessor] do
      wd = Dir.pwd
      chdir @output_dir
      sh "#{RUBY_COMMAND} ../#{@psalm_preprocessor} #{ofop} #{@@czech_psalm_options} ../#{syrovy}"
      chdir wd
    end
    return of_fullpath
  end

  # Rake task to notate first verse of a psalm
  def geninitium(psalm, tone)
    ntone = tone
    if i = ntone.index('.') then
      ntone = ntone[0..i-1].downcase+'-'+ntone[i+1..-1]
    end
    patternfile = @psalmtones_dir+ntone+'-auto.gabc'

    psalmfile = @psalms_dir + '/' + psalm
  
    i = File.basename(patternfile).index('.')
    output_ending = '-initium-'+File.basename(patternfile)[0..i-1]+'.gabc'
    outputfile = File.basename(psalmfile).gsub(/\.pslm$/, output_ending)

    initium_tool = @instrumenta_dir+'initiumpsalmi.rb'

    file @output_dir+outputfile => [psalmfile, patternfile, initium_tool] do
      wd = Dir.pwd
      chdir @output_dir
      sh "ruby ../#{initium_tool} ../#{psalmfile} ../#{patternfile}"
      chdir wd
    end

    return gregorio(@output_dir+outputfile)
  end
end

# some functions not bound to the data owned by TaskGenerator
module Hiram

  # generate a Rake task to compile a GABC file
  def gregorio(srcf)
    f2 = srcf.gsub(".gabc", ".tex")
    file f2 => [srcf] do
      wd = Dir.pwd
      chdir File.dirname(srcf)
      sh "gregorio #{File.basename srcf}"
      chdir wd
    end
    return f2
  end

  TONI_PSALMORUM = {
    'I.D' => [[2,0], [1,2]],
    'I.D2' => [[2,0], [1,2]],
    'I.f' => [[2,0], [1,2]],
    'I.g' => [[2,0], [1,2]],
    'Isoll.D2' => [[1,3], [1,2]],
    'Isoll.g' => [[1,3], [1,2]],
    'II.D' => [[1,0], [1,1]],
    'III.a' => [[2,0], [2,0]],
    'IV.E' => [[1,2], [1,3]],
    'VI.F' => [[1,1], [1,2]],
    'VII.a' => [[2,0], [2,0]],
    'VII.c' => [[2,0], [2,0]],
    'VII.d' => [[2,0], [2,0]],
    'VIIsoll.a' => [[2,0], [2,0]],
    'VIII.G' => [[1,0], [1,2]],
    'VIII.c' => [[1,0], [1,2]],
    'VIII.G*' => [[1,0], [1,2]],
    'VIIIsoll.G' => [[1,3], [1,2]],
    'VIIIsoll.G2' => [[1,3], [1,2]],
    'per' => [[1,3], [1,1]],
    'dir' => [[1,2], [1,0]]
  }

  # takes a psalmtone (String like 'I.g') and returns options
  # for psalmpreprocessor.rb to point a psalm for this tone
  def options_accents(psalmtone)
    if TONI_PSALMORUM[psalmtone] == nil then
      raise ArgumentError, "Unknown psalm tone '#{psalmtone}'."
    end

    accents = 
      TONI_PSALMORUM[psalmtone][0][0].to_s + ':' + 
      TONI_PSALMORUM[psalmtone][1][0].to_s
    preps = 
      TONI_PSALMORUM[psalmtone][0][1].to_s + ':' + 
      TONI_PSALMORUM[psalmtone][1][1].to_s
    
    return "--accents #{accents} --preparatory-syllables #{preps}"
  end
end