#!/usr/bin/env ruby

require 'set'

class G2DiaryIndex
  INDEX_FILE = ENV['G2_INDEX_FILE'] || './index.g2'

  KANA_MAP = {
    '｡' => [ '。', nil, nil ],
    '｢' => [ '「', nil, nil ],
    '｣' => [ '」', nil, nil ],
    '､' => [ '、', nil, nil ],
    '･' => [ '・', nil, nil ],
    'ｦ' => [ 'ヲ', nil, nil ],
    'ｧ' => [ 'ァ', nil, nil ],
    'ｨ' => [ 'ィ', nil, nil ],
    'ｩ' => [ 'ゥ', nil, nil ],
    'ｪ' => [ 'ェ', nil, nil ],
    'ｫ' => [ 'ォ', nil, nil ],
    'ｬ' => [ 'ャ', nil, nil ],
    'ｭ' => [ 'ュ', nil, nil ],
    'ｮ' => [ 'ョ', nil, nil ],
    'ｯ' => [ 'ッ', nil, nil ],
    'ｰ' => [ 'ー', nil, nil ],
    'ｱ' => [ 'ア', nil, nil ],
    'ｲ' => [ 'イ', nil, nil ],
    'ｳ' => [ 'ウ', 'ヴ', nil ],
    'ｴ' => [ 'エ', nil, nil ],
    'ｵ' => [ 'オ', nil, nil ],
    'ｶ' => [ 'カ', 'ガ', nil ],
    'ｷ' => [ 'キ', 'ギ', nil ],
    'ｸ' => [ 'ク', 'グ', nil ],
    'ｹ' => [ 'ケ', 'ゲ', nil ],
    'ｺ' => [ 'コ', 'ゴ', nil ],
    'ｻ' => [ 'サ', 'ザ', nil ],
    'ｼ' => [ 'シ', 'ジ', nil ],
    'ｽ' => [ 'ス', 'ズ', nil ],
    'ｾ' => [ 'セ', 'ゼ', nil ],
    'ｿ' => [ 'ソ', 'ゾ', nil ],
    'ﾀ' => [ 'タ', 'ダ', nil ],
    'ﾁ' => [ 'チ', 'ヂ', nil ],
    'ﾂ' => [ 'ツ', 'ヅ', nil ],
    'ﾃ' => [ 'テ', 'デ', nil ],
    'ﾄ' => [ 'ト', 'ド', nil ],
    'ﾅ' => [ 'ナ', nil, nil ],
    'ﾆ' => [ 'ニ', nil, nil ],
    'ﾇ' => [ 'ヌ', nil, nil ],
    'ﾈ' => [ 'ネ', nil, nil ],
    'ﾉ' => [ 'ノ', nil, nil ],
    'ﾊ' => [ 'ハ', 'バ', 'パ' ],
    'ﾋ' => [ 'ヒ', 'ビ', 'ピ' ],
    'ﾌ' => [ 'フ', 'ブ', 'プ' ],
    'ﾍ' => [ 'ヘ', 'ベ', 'ペ' ],
    'ﾎ' => [ 'ホ', 'ボ', 'ポ' ],
    'ﾏ' => [ 'マ', nil, nil ],
    'ﾐ' => [ 'ミ', nil, nil ],
    'ﾑ' => [ 'ム', nil, nil ],
    'ﾒ' => [ 'メ', nil, nil ],
    'ﾓ' => [ 'モ', nil, nil ],
    'ﾔ' => [ 'ヤ', nil, nil ],
    'ﾕ' => [ 'ユ', nil, nil ],
    'ﾖ' => [ 'ヨ', nil, nil ],
    'ﾗ' => [ 'ラ', nil, nil ],
    'ﾘ' => [ 'リ', nil, nil ],
    'ﾙ' => [ 'ル', nil, nil ],
    'ﾚ' => [ 'レ', nil, nil ],
    'ﾛ' => [ 'ロ', nil, nil ],
    'ﾜ' => [ 'ワ', nil, nil ],
    'ﾝ' => [ 'ン', nil, nil ],
    'ﾞ' => [ '゛', nil, nil ],
    'ﾟ' => [ '゜', nil, nil ],
  }

  def initialize(make_new)
    @index = make_new ? {} : load
  end

  def load
    File.open(INDEX_FILE) do |f|
      Marshal.load(f)
    end
  end

  def save
    new_path = "#{INDEX_FILE}.new"
    File.open(new_path, "w") do |f|
      Marshal.dump(@index, f)
    end
    begin
      File.unlink(INDEX_FILE)
    rescue Errno::ENOENT
    end
    File.rename(new_path, INDEX_FILE)
  end

  def normalize(str)
    str = str
            # 全角英数記号 http://www.asahi-net.or.jp/~ax2s-kmtn/ref/unicode/uff00.html
            .tr("\u{ff01}-\u{ff5e}", '!-~')
            # quote文字 https://0g0.org/category/2000-206F/1/
            .tr("\u{2018}\u{2019}\u{201a}\u{201b}\u{2032}\u{2035}", "`',`'`")
            .tr("\u{201c}\u{201d}\u{201e}\u{201f}\u{2033}\u{2036}", '"')
            # 円マーク
            .tr('￥', '¥')
            # ハイフン文字 https://garabakos.sakura.ne.jp/Finfs/infs00976.htm
            .tr("\u{2010}\u{2212}\u{2014}\u{2015}\u{30fc}", '-')
            # 空白文字 https://blog1.mammb.com/entry/2021/11/11/090000
            .tr("\u{00a0}\u{2000}-\u{200a}\u{202f}\u{205f}\u{3000}\u{200b}\u{feff}", ' ')
            # downcase
            .tr('A-Z', 'a-z')
    res = ''
    i = 0
    len = str.length
    while i < len do
      chari = str[i]
      cans = KANA_MAP[chari]
      if cans.nil?
        res << chari
        i += 1
        next
      end
      if cans[1] && str[i + 1] == 'ﾞ'
        res << cans[1]
        i += 2
        next
      end
      if cans[2] && str[i + 1] == 'ﾟ'
        res << cans[2]
        i += 2
        next
      end
      res << cans[0]
      i += 1
    end
    res
  end

  def string_to_bigram(str)
    str = normalize(str)

    kws = {}

    str.each_char do |c|
      next if c =~ /\s/    # 空白文字だったら無視
      kws[c] = true
    end

    (0...str.length-1).each do |i|
      cc = str[i, 2]
      next if cc =~ /\s/    # 空白文字を含んでたら無視
      kws[cc] = true
    end

    kws
  end

  def add_file(path)
    data = File.read(path)
    string_to_bigram(data).each do |kw, _|
      @index[kw] ||= {}         # スピードのため Hash を使う。Set は遅い
      @index[kw][path] = true
    end
  end

  def remove_file(path)
    @index.each do |kw, paths|
      paths.delete(path)
    end
  end

  def paths_of(kw)
    @index[kw]&.dup || {}
  end

  def search(str)
    kws = string_to_bigram(str)
    if kws.empty?
      return {}
    end
    paths = paths_of(kws.keys.first)
    kws.each do |kw, _|
      paths = paths.slice(*paths_of(kw).keys)
    end
    str = normalize(str)
    paths.select! do |path|
      data = File.read(path)
      data = normalize(data)
      data.include? str
    end
    paths
  end

  def all_docs
    r = {}
    @index.each do |_, paths|
      r.merge!(paths)
    end
    r
  end
end
