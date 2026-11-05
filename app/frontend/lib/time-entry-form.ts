export function toggleSelectedTag(tagIds: number[], tagId: number) {
  return tagIds.includes(tagId)
    ? tagIds.filter((id) => id !== tagId)
    : [...tagIds, tagId];
}
