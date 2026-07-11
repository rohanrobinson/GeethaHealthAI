/**
 * Test/sample documents for the Documents page and Upload Document modal.
 * Use for development, demos, or as seed data. Shape matches what the modal produces.
 */
export type DocumentRecord = {
  id: string
  name: string
  memberId: string
  memberName: string
  uploadedAt?: string
}

export const TEST_DOCUMENTS: DocumentRecord[] = [
  {
    id: 'doc-test-1',
    name: 'Annual physical summary',
    memberId: '', // no member linked; UI can show "—" or "Family"
    memberName: '—',
    uploadedAt: '2024-01-15',
  },
  {
    id: 'doc-test-2',
    name: 'Lab results - CBC',
    memberId: '', // assign to a member when you have family data
    memberName: '—',
    uploadedAt: '2024-02-01',
  },
  {
    id: 'doc-test-3',
    name: 'Prescription - Lisinopril',
    memberId: '',
    memberName: '—',
    uploadedAt: '2024-02-10',
  },
  {
    id: 'doc-test-4',
    name: 'Immunization record',
    memberId: '',
    memberName: '—',
    uploadedAt: '2024-01-28',
  },
  {
    id: 'doc-test-5',
    name: 'Specialist referral - Cardiology',
    memberId: '',
    memberName: '—',
    uploadedAt: '2024-03-05',
  },
]
