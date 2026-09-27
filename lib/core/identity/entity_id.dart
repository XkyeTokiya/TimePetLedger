/// 调用方在本地生成并显式传入的 UUID v4 不透明字符串（Q-018）。
///
/// 构造领域对象时不生成身份，不从时间戳、标题或其他字段推导身份。
/// 此别名沿用 String；领域关联只按完整标识比较，不解析业务含义。
typedef EntityId = String;

/// 校验 UUID v4 输入的标准分组、版本位和变体位，保留原字符串。
///
/// 不生成随机数、不规范化大小写，也不承担存储唯一性检查。
EntityId requireUuidV4(EntityId id) {
  final pattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-4[0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  );
  if (id.length != 36 || !pattern.hasMatch(id)) {
    throw ArgumentError.value(id, 'id', 'Must be a UUID v4');
  }
  return id;
}
