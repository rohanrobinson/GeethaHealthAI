import type { FamilyMember } from './familyStorage.ts'

export type AncestryTierId = 'grandparent' | 'parent' | 'adult' | 'child' | 'other'

export type AncestryTier = {
  id: AncestryTierId
  label: string
  order: number
}

export const ANCESTRY_TIERS: AncestryTier[] = [
  { id: 'grandparent', label: 'Grandparents', order: 0 },
  { id: 'parent', label: 'Parents', order: 1 },
  { id: 'adult', label: 'Adults', order: 2 },
  { id: 'child', label: 'Children', order: 3 },
  { id: 'other', label: 'Family', order: 4 },
]

const TIER_BY_ID = new Map(ANCESTRY_TIERS.map((tier) => [tier.id, tier]))

const ROLE_PATTERNS: Record<AncestryTierId, RegExp[]> = {
  grandparent: [
    /\bgrand(?:father|mother|pa|ma|parent|dad|mom)?\b/i,
    /\b(?:nana|nanna|gramps|granny)\b/i,
  ],
  parent: [/\b(?:father|mother|dad|mom|mama|papa|parent)\b/i],
  child: [/\b(?:son|daughter|child|kid|baby|infant|toddler)\b/i],
  adult: [
    /\b(?:husband|wife|spouse|partner|sibling|brother|sister|aunt|uncle|cousin|niece|nephew)\b/i,
  ],
  other: [],
}

const MALE_ROLE = /\b(?:father|dad|grandfather|grandpa|son|brother|husband|uncle|nephew|him|he)\b/i
const FEMALE_ROLE = /\b(?:mother|mom|grandmother|grandma|daughter|sister|wife|aunt|niece|her|she)\b/i
const SPOUSE_ROLE = /\b(?:husband|wife|spouse|partner)\b/i

export type AncestryLayout = {
  tiers: { tier: AncestryTier; members: FamilyMember[] }[]
  couplePairs: [string, string][]
  parentChildLinks: { parentId: string; childId: string }[]
}

export function classifyMemberTier(role: string): AncestryTierId {
  const normalized = role.trim()
  if (!normalized) {
    return 'other'
  }

  for (const tier of ANCESTRY_TIERS) {
    if (tier.id === 'other') {
      continue
    }
    const patterns = ROLE_PATTERNS[tier.id]
    if (patterns.some((pattern) => pattern.test(normalized))) {
      return tier.id
    }
  }

  return 'other'
}

function parseAge(age: string): number | null {
  const value = Number.parseInt(age.trim(), 10)
  return Number.isFinite(value) ? value : null
}

function sortMembersInTier(members: FamilyMember[]): FamilyMember[] {
  return [...members].sort((left, right) => {
    const leftAge = parseAge(left.age)
    const rightAge = parseAge(right.age)
    if (leftAge !== null && rightAge !== null && leftAge !== rightAge) {
      return rightAge - leftAge
    }
    return left.firstName.localeCompare(right.firstName)
  })
}

function isMaleRole(role: string): boolean {
  return MALE_ROLE.test(role)
}

function isFemaleRole(role: string): boolean {
  return FEMALE_ROLE.test(role)
}

function pairCouplesInTier(members: FamilyMember[]): [string, string][] {
  const pairs: [string, string][] = []
  const used = new Set<string>()

  const spouses = members.filter((member) => SPOUSE_ROLE.test(member.role))
  for (const spouse of spouses) {
    if (used.has(spouse.id)) {
      continue
    }
    const partner = members.find(
      (candidate) =>
        candidate.id !== spouse.id &&
        !used.has(candidate.id) &&
        (SPOUSE_ROLE.test(candidate.role) ||
          (isMaleRole(spouse.role) && isFemaleRole(candidate.role)) ||
          (isFemaleRole(spouse.role) && isMaleRole(candidate.role)))
    )
    if (partner) {
      pairs.push([spouse.id, partner.id])
      used.add(spouse.id)
      used.add(partner.id)
    }
  }

  const fathers = members.filter(
    (member) => !used.has(member.id) && /\b(?:father|dad)\b/i.test(member.role)
  )
  const mothers = members.filter(
    (member) => !used.has(member.id) && /\b(?:mother|mom)\b/i.test(member.role)
  )

  for (const father of fathers) {
    const mother = mothers.find((candidate) => !used.has(candidate.id))
    if (mother) {
      pairs.push([father.id, mother.id])
      used.add(father.id)
      used.add(mother.id)
    }
  }

  return pairs
}

const INFER_PARENT_TIERS: Partial<Record<AncestryTierId, AncestryTierId[]>> = {
  child: ['parent', 'adult'],
  parent: ['grandparent'],
}

function dedupeParentChildLinks(
  links: { parentId: string; childId: string }[]
): { parentId: string; childId: string }[] {
  const seen = new Set<string>()
  return links.filter((link) => {
    const key = `${link.parentId}:${link.childId}`
    if (seen.has(key)) {
      return false
    }
    seen.add(key)
    return true
  })
}

function buildParentChildLinks(members: FamilyMember[]): { parentId: string; childId: string }[] {
  const memberById = new Map(members.map((member) => [member.id, member]))
  const links: { parentId: string; childId: string }[] = []

  for (const child of members) {
    const explicitParentIds =
      child.parentIds?.filter(
        (parentId) => parentId !== child.id && memberById.has(parentId)
      ) ?? []

    if (explicitParentIds.length > 0) {
      for (const parentId of explicitParentIds) {
        links.push({ parentId, childId: child.id })
      }
      continue
    }

    const childTierId = classifyMemberTier(child.role)
    const parentTierIds = INFER_PARENT_TIERS[childTierId]
    if (!parentTierIds) {
      continue
    }

    for (const parentTierId of parentTierIds) {
      const parents = members.filter(
        (member) =>
          member.id !== child.id && classifyMemberTier(member.role) === parentTierId
      )
      for (const parent of parents) {
        links.push({ parentId: parent.id, childId: child.id })
      }
    }
  }

  return dedupeParentChildLinks(links)
}

export function buildAncestryLayout(members: FamilyMember[]): AncestryLayout {
  const grouped = new Map<AncestryTierId, FamilyMember[]>()
  for (const tier of ANCESTRY_TIERS) {
    grouped.set(tier.id, [])
  }

  for (const member of members) {
    const tierId = classifyMemberTier(member.role)
    grouped.get(tierId)?.push(member)
  }

  const tiers = ANCESTRY_TIERS.map((tier) => ({
    tier,
    members: sortMembersInTier(grouped.get(tier.id) ?? []),
  })).filter((entry) => entry.members.length > 0)

  const couplePairs = tiers.flatMap((entry) => pairCouplesInTier(entry.members))
  const parentChildLinks = buildParentChildLinks(members)

  return { tiers, couplePairs, parentChildLinks }
}

export function getTierLabel(tierId: AncestryTierId): string {
  return TIER_BY_ID.get(tierId)?.label ?? 'Family'
}
