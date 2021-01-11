require 'test_helper'
require 'review/htmlbuilder'
require 'review/img_math'
require 'mini_magick'

class ImgMathTest < Test::Unit::TestCase
  def setup
    @config = ReVIEW::Configure.values
    @tmpdir = Dir.mktmpdir
    @config.merge!(
      'math_format' => 'imgmath',
      'texcommand' => 'uplatex',
      'imagedir' => @tmpdir
    )
    @config['imgmath_options']['fontsize'] = 24
    @img_math = ReVIEW::ImgMath.new(@config)
  end

  def teardown
    @img_math.cleanup_mathimg
    FileUtils.rm_rf(@tmpdir)
  end

  def test_defer_math_image_pathname
    str1 = '$A > B \\gg C$'
    key1 = Digest::SHA256.hexdigest(str1)
    img_path1 = @img_math.defer_math_image(str1, key1)
    @img_math.make_math_images

    assert File.exist?(img_path1)

    assert_equal "_gen_#{key1}.png", File.basename(img_path1)
  end

  def test_defer_math_image
    str1 = '$\\sum_{i=1}^nf_n(x) \\in \\mathbb{R}$'
    key1 = Digest::SHA256.hexdigest(str1)
    img_path1 = @img_math.defer_math_image(str1, key1)
    str2 = '$\\sum_{i=1}^nf_n(X) \\in \\mathbb{R}$'
    key2 = Digest::SHA256.hexdigest(str2)
    img_path2 = @img_math.defer_math_image(str2, key2)
    @img_math.make_math_images

    assert File.exist?(img_path1)
    assert File.exist?(img_path2)

    val1 = compare_images(img_path1, File.join(assets_dir, 'img_math/img1.png'))
    assert_equal 0, val1

    val2 = compare_images(img_path2, File.join(assets_dir, 'img_math/img2.png'))
    assert_equal 0, val2

    val3 = compare_images(img_path1, img_path2)
    assert val3 > 100
  end

  def test_make_math_image_pathname
    str1 = '$A > B \\gg C$'
    key1 = Digest::SHA256.hexdigest(str1)
    img_path1 = @img_math.make_math_image(str1, key1)
    @img_math.make_math_images

    assert File.exist?(img_path1)

    assert_equal "_gen_#{key1}.png", File.basename(img_path1)
  end

  def test_make_math_image
    str1 = '$A > B \\gg C$'
    key1 = Digest::SHA256.hexdigest(str1)
    img_path1 = @img_math.make_math_image(str1, key1)

    assert File.exist?(img_path1)

    val1 = compare_images(img_path1, File.join(assets_dir, 'img_math/img3.png'))
    assert_equal 0, val1
  end

  def compare_images(image1, image2)
    compare = MiniMagick::Tool::Compare.new(whiny: false)
    compare.metric('AE')
    compare << image1
    compare << image2
    compare << File.join(@tmpdir, 'diff.jpg')

    compare.call do |_, dist, _|
      return dist.to_i
    end
  end
end
