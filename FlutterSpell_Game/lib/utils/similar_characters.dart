/// Groups of look-alike / sound-alike hanzi, used to build distractors for
/// fill-in-the-character exercises.
const List<String> _similarGroups = [
  '寄奇骑椅',
  '出击岀凸',
  '信倍借估',
  '件牛伴华',
  '己已巳已',
  '未末木本',
  '日曰目白',
  '土士工干',
  '人入八大',
  '太大犬天夫',
  '天夭夫关',
  '问间闻间',
  '休体林你',
  '他她它地也',
  '请清情晴睛',
  '青清情请',
  '请诸谁说',
  '候侯猴',
  '买卖实',
  '问同间闷',
  '远园还运近',
  '进近过',
  '找我戏成',
  '住往主柱注',
  '班斑现球',
  '再冉苒',
  '午牛干千',
  '今令含合',
  '东车东乐',
  '师帅',
  '看着者香',
  '里理黑墨',
  '校较交',
  '校板极',
  '座坐做作',
  '作昨做',
  '在再存',
  '友支反发',
  '朋明胖服',
  '草早苹菜',
  '吗妈马吗',
  '妈姐姑',
  '哥歌可',
  '姐组祖',
  '很狠跟',
  '得德待',
  '的约勺',
  '写与',
  '里理埋',
  '河何可荷',
  '海每梅',
  '候后厚',
  '没设投',
  '学字孝',
  '字宇守',
  '手毛千',
  '买头实',
  '快块决',
  '常带尝',
  '站坐占',
  '想相箱',
  '晚脱免',
  '新亲辛',
  '送关进',
  '寄寂客宿',
  '邮由油曲',
  '递第弟',
  '电由甲申',
  '话活舌',
  '语话读',
  '读续卖',
  '说谈脱',
];

/// Up to [count] characters that resemble [target], shuffled by [pick].
/// Returns fewer when the table has fewer matches.
List<String> similarCharacters(String target, int count) {
  final found = <String>[];
  for (final group in _similarGroups) {
    if (!group.contains(target)) continue;
    for (final ch in group.split('')) {
      if (ch != target && !found.contains(ch)) found.add(ch);
    }
  }
  return found;
}
