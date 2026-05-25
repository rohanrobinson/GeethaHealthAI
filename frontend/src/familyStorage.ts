export type Condition = {
  id: string
  name: string
  notes?: string
}

export type Medication = {
  id: string
  name: string
  dosage?: string
  frequency?: string
  notes?: string
}

export type Appointment = {
  id: string
  description: string
  date: string
  time?: string
  location?: string
  notes?: string
}

export type ReportLinkType = 'condition' | 'appointment'

export type Report = {
  id: string
  title: string
  filePath: string
  linkType: ReportLinkType
  linkedId: string
  notes?: string
  createdAt: string
}

export type FamilyMember = {
  id: string
  firstName: string
  age: string
  role: string
  parentIds?: string[]
  conditions?: Condition[]
  medications?: Medication[]
  appointments?: Appointment[]
  reports?: Report[]
}

type FamilyStorage = {
  familyName: string
  members: FamilyMember[]
}

const STORAGE_KEY = 'geetha-family'

const normalizeParentIds = (value: unknown, memberId: string): string[] => {
  if (!Array.isArray(value)) {
    return []
  }
  return value.filter(
    (id): id is string => typeof id === 'string' && id.length > 0 && id !== memberId
  )
}

const normalizeMember = (member: FamilyMember): FamilyMember => ({
  id: member.id,
  firstName: member.firstName,
  age: member.age ?? '',
  role: member.role ?? '',
  parentIds: normalizeParentIds(member.parentIds, member.id),
  conditions: Array.isArray(member.conditions) ? member.conditions : [],
  medications: Array.isArray(member.medications) ? member.medications : [],
  appointments: Array.isArray(member.appointments) ? member.appointments : [],
  reports: Array.isArray(member.reports) ? member.reports : [],
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

export const formatParentNames = (
  parentIds: string[] | undefined,
  members: FamilyMember[]
): string => {
  if (!parentIds?.length) {
    return ''
  }
  const names = parentIds
    .map((id) => members.find((member) => member.id === id)?.firstName)
    .filter((name): name is string => Boolean(name))
  return names.length > 0 ? names.join(', ') : ''
}

export const clearFamilyStorage = () => {
  if (typeof window === 'undefined') {
    return
  }

  window.localStorage.removeItem(STORAGE_KEY)
}
