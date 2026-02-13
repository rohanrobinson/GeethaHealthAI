type FamilyMember = {
  id: string
  firstName: string
  age: string
  role: string
}

type FamilyStorage = {
  familyName: string
  members: FamilyMember[]
}

const STORAGE_KEY = 'geetha-family'

const normalizeMember = (member: FamilyMember): FamilyMember => ({
  id: member.id,
  firstName: member.firstName,
  age: member.age ?? '',
  role: member.role ?? '',
})

const isValidMember = (value: unknown): value is FamilyMember => {
  if (!value || typeof value !== 'object') {
    return false
  }

  const record = value as Record<string, unknown>
  return typeof record.id === 'string' && typeof record.firstName === 'string'
}

export const getFamilyStorage = (): FamilyStorage | null => {
  if (typeof window === 'undefined') {
    return null
  }

  const raw = window.localStorage.getItem(STORAGE_KEY)
  if (!raw) {
    return null
  }

  try {
    const parsed = JSON.parse(raw) as Partial<FamilyStorage>
    const familyName = typeof parsed.familyName === 'string' ? parsed.familyName : ''
    const members = Array.isArray(parsed.members)
      ? parsed.members.filter(isValidMember).map(normalizeMember)
      : []

    return { familyName, members }
  } catch {
    return null
  }
}

export const saveFamilyStorage = (data: FamilyStorage) => {
  if (typeof window === 'undefined') {
    return
  }

  window.localStorage.setItem(STORAGE_KEY, JSON.stringify(data))
}

export const updateMemberStorage = (
  memberId: string,
  updates: Partial<FamilyMember>
): FamilyStorage | null => {
  const current = getFamilyStorage()
  if (!current) {
    return null
  }

  const members = current.members.map((member) =>
    member.id === memberId ? { ...member, ...updates } : member
  )
  const updated = { ...current, members }
  saveFamilyStorage(updated)
  return updated
}

export const clearFamilyStorage = () => {
  if (typeof window === 'undefined') {
    return
  }

  window.localStorage.removeItem(STORAGE_KEY)
}
