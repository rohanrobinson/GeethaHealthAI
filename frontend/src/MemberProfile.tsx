import { useEffect, useMemo, useState } from 'react'
import { useLocation, useNavigate, useParams } from 'react-router-dom'
import { Tabs } from '@mantine/core'
import { recognize } from 'tesseract.js'
import {
  type Condition,
  type FamilyMember,
  type Medication,
  type Appointment,
  type Report,
  type ReportLinkType,
  getFamilyStorage,
  updateMemberStorage,
} from './familyStorage.ts'

type MemberProfileState = {
  familyName?: string
  members?: FamilyMember[]
}

type AddResourceModal = 'condition' | 'medication' | 'appointment' | 'report' | null
type ReportAnalysisData = {
  linkedLabel: string
  detectedReportType: string
  extractedValues: string[]
  interpretation: string[]
}

type ReportAnalysisState =
  | { status: 'idle' }
  | { status: 'loading' }
  | { status: 'ready'; data: ReportAnalysisData }
  | { status: 'error'; message: string }

const AVAILABLE_REPORT_PATHS = Object.keys(
  import.meta.glob('/public/medical/reports/*')
)
  .filter((filePath) => /\.(png|jpe?g|gif|webp|avif)$/i.test(filePath))
  .map((filePath) => filePath.replace('/public', ''))
  .sort((a, b) => a.localeCompare(b))

function EditIcon({ size = 18, title = 'Edit' }: { size?: number; title?: string }) {
  return (
    <svg
      xmlns="http://www.w3.org/2000/svg"
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
      role="img"
      aria-label={title}
    >
      <title>{title}</title>
      <path d="M17 3a2.85 2.83 0 1 1 4 4L7.5 20.5 2 22l1.5-5.5Z" />
      <path d="m15 5 4 4" />
    </svg>
  )
}

function TrashIcon({ size = 18, title = 'Delete' }: { size?: number; title?: string }) {
  return (
    <svg
      xmlns="http://www.w3.org/2000/svg"
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
      role="img"
      aria-label={title}
    >
      <title>{title}</title>
      <path d="M3 6h18" />
      <path d="M8 6V4h8v2" />
      <path d="M19 6l-1 14H6L5 6" />
      <path d="M10 11v6" />
      <path d="M14 11v6" />
    </svg>
  )
}

function PictureIcon({ size = 18, title = 'View image' }: { size?: number; title?: string }) {
  return (
    <svg
      xmlns="http://www.w3.org/2000/svg"
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
      role="img"
      aria-label={title}
    >
      <title>{title}</title>
      <rect x="3" y="3" width="18" height="18" rx="2" ry="2" />
      <circle cx="8.5" cy="8.5" r="1.5" />
      <path d="M21 15l-5-5L5 21" />
    </svg>
  )
}

function MemberProfile() {
  const navigate = useNavigate()
  const { memberId } = useParams()
  const location = useLocation()
  const state = location.state as MemberProfileState | null
  const storedFamily = getFamilyStorage()

  const [familyData, setFamilyData] = useState<{
    familyName: string
    members: FamilyMember[]
  }>(() => {
    if (state?.members?.length) {
      return {
        familyName: state.familyName ?? storedFamily?.familyName ?? '',
        members: state.members,
      }
    }
    return {
      familyName: storedFamily?.familyName ?? '',
      members: storedFamily?.members ?? [],
    }
  })

  const members = familyData.members
  const member = useMemo(
    () => members.find((item) => item.id === memberId),
    [members, memberId]
  )

  const [firstName, setFirstName] = useState(member?.firstName ?? '')
  const [age, setAge] = useState(member?.age ?? '')
  const [role, setRole] = useState(member?.role ?? '')

  const familyName = familyData.familyName
  const familyLabel = familyName ? `${familyName} Family` : 'Family'

  const [addModal, setAddModal] = useState<AddResourceModal>(null)
  const [conditionName, setConditionName] = useState('')
  const [conditionNotes, setConditionNotes] = useState('')
  const [medicationName, setMedicationName] = useState('')
  const [medicationDosage, setMedicationDosage] = useState('')
  const [medicationFrequency, setMedicationFrequency] = useState('')
  const [medicationNotes, setMedicationNotes] = useState('')
  const [appointmentDescription, setAppointmentDescription] = useState('')
  const [appointmentDate, setAppointmentDate] = useState('')
  const [appointmentTime, setAppointmentTime] = useState('')
  const [appointmentLocation, setAppointmentLocation] = useState('')
  const [appointmentNotes, setAppointmentNotes] = useState('')
  const [reportTitle, setReportTitle] = useState('')
  const [reportFilePath, setReportFilePath] = useState(AVAILABLE_REPORT_PATHS[0] ?? '')
  const [reportLinkType, setReportLinkType] = useState<ReportLinkType>('condition')
  const [reportLinkedId, setReportLinkedId] = useState('')
  const [reportNotes, setReportNotes] = useState('')

  const [conditions, setConditions] = useState<Condition[]>(() => member?.conditions ?? [])
  const [medications, setMedications] = useState<Medication[]>(() => member?.medications ?? [])
  const [appointments, setAppointments] = useState<Appointment[]>(() => member?.appointments ?? [])
  const [reports, setReports] = useState<Report[]>(() => member?.reports ?? [])

  const [editingBasics, setEditingBasics] = useState(false)
  const [editingConditionId, setEditingConditionId] = useState<string | null>(null)
  const [editingMedicationId, setEditingMedicationId] = useState<string | null>(null)
  const [editingAppointmentId, setEditingAppointmentId] = useState<string | null>(null)
  const [viewingReport, setViewingReport] = useState<Report | null>(null)
  const [isReportAnalysisVisible, setIsReportAnalysisVisible] = useState(false)
  const [reportAnalysisState, setReportAnalysisState] = useState<ReportAnalysisState>({ status: 'idle' })

  useEffect(() => {
    if (member) {
      setConditions(member.conditions ?? [])
      setMedications(member.medications ?? [])
      setAppointments(member.appointments ?? [])
      setReports(member.reports ?? [])
    }
  // Sync editable lists when switching to a different member
  // eslint-disable-next-line react-hooks/exhaustive-deps -- only when member identity changes
  }, [member?.id])

  const selectedLinkOptions = reportLinkType === 'condition' ? conditions : appointments

  const handleSubmit = (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault()
    if (!memberId) return
    const updated = updateMemberStorage(memberId, {
      firstName: firstName.trim(),
      age: age.trim(),
      role: role.trim(),
      conditions,
      medications,
      appointments,
    })
    if (updated) {
      setFamilyData({ familyName: updated.familyName, members: updated.members })
      navigate('/family-profile', {
        state: { familyName: updated.familyName, members: updated.members },
      })
    }
  }

  const closeAddModal = () => {
    setAddModal(null)
    setConditionName('')
    setConditionNotes('')
    setMedicationName('')
    setMedicationDosage('')
    setMedicationFrequency('')
    setMedicationNotes('')
    setAppointmentDescription('')
    setAppointmentDate('')
    setAppointmentTime('')
    setAppointmentLocation('')
    setAppointmentNotes('')
    setReportTitle('')
    setReportFilePath(AVAILABLE_REPORT_PATHS[0] ?? '')
    setReportLinkType('condition')
    setReportLinkedId('')
    setReportNotes('')
  }

  const openAddReportModal = (preferredType: ReportLinkType, linkedId?: string) => {
    if (preferredType === 'condition') {
      setReportLinkType('condition')
      setReportLinkedId(linkedId ?? conditions[0]?.id ?? '')
    } else {
      setReportLinkType('appointment')
      setReportLinkedId(linkedId ?? appointments[0]?.id ?? '')
    }
    setReportFilePath(AVAILABLE_REPORT_PATHS[0] ?? '')
    setAddModal('report')
  }

  const handleAddCondition = (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault()
    if (!memberId || !member) return
    const name = conditionName.trim()
    if (!name) return
    const newCondition: Condition = {
      id: crypto.randomUUID(),
      name,
      notes: conditionNotes.trim() || undefined,
    }
    const updated = updateMemberStorage(memberId, {
      conditions: [...conditions, newCondition],
    })
    if (updated) {
      setFamilyData({ familyName: updated.familyName, members: updated.members })
      setConditions((prev) => [...prev, newCondition])
      closeAddModal()
    }
  }

  const handleAddMedication = (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault()
    if (!memberId || !member) return
    const name = medicationName.trim()
    if (!name) return
    const newMedication: Medication = {
      id: crypto.randomUUID(),
      name,
      dosage: medicationDosage.trim() || undefined,
      frequency: medicationFrequency.trim() || undefined,
      notes: medicationNotes.trim() || undefined,
    }
    const updated = updateMemberStorage(memberId, {
      medications: [...medications, newMedication],
    })
    if (updated) {
      setFamilyData({ familyName: updated.familyName, members: updated.members })
      setMedications((prev) => [...prev, newMedication])
      closeAddModal()
    }
  }

  const handleAddAppointment = (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault()
    if (!memberId || !member) return
    const description = appointmentDescription.trim()
    if (!description) return
    const date = appointmentDate.trim()
    if (!date) return
    const newAppointment: Appointment = {
      id: crypto.randomUUID(),
      description,
      date,
      time: appointmentTime.trim() || undefined,
      location: appointmentLocation.trim() || undefined,
      notes: appointmentNotes.trim() || undefined,
    }
    const updated = updateMemberStorage(memberId, {
      appointments: [...appointments, newAppointment],
    })
    if (updated) {
      setFamilyData({ familyName: updated.familyName, members: updated.members })
      setAppointments((prev) => [...prev, newAppointment])
      closeAddModal()
    }
  }

  const handleAddReport = (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault()
    if (!memberId || !member) return
    const title = reportTitle.trim()
    const filePath = reportFilePath.trim()
    if (!title || !filePath || !reportLinkedId) return
    const newReport: Report = {
      id: crypto.randomUUID(),
      title,
      filePath,
      linkType: reportLinkType,
      linkedId: reportLinkedId,
      notes: reportNotes.trim() || undefined,
      createdAt: new Date().toISOString(),
    }
    const updated = updateMemberStorage(memberId, {
      reports: [...reports, newReport],
    })
    if (updated) {
      setFamilyData({ familyName: updated.familyName, members: updated.members })
      setReports((prev) => [...prev, newReport])
      closeAddModal()
    }
  }

  const updateCondition = (id: string, patch: Partial<Condition>) => {
    setConditions((prev) =>
      prev.map((c) => (c.id === id ? { ...c, ...patch } : c))
    )
  }
  const removeCondition = (id: string) => {
    setConditions((prev) => prev.filter((c) => c.id !== id))
  }
  const updateMedication = (id: string, patch: Partial<Medication>) => {
    setMedications((prev) =>
      prev.map((m) => (m.id === id ? { ...m, ...patch } : m))
    )
  }
  const removeMedication = (id: string) => {
    setMedications((prev) => prev.filter((m) => m.id !== id))
  }
  const updateAppointment = (id: string, patch: Partial<Appointment>) => {
    setAppointments((prev) =>
      prev.map((a) => (a.id === id ? { ...a, ...patch } : a))
    )
  }
  const removeAppointment = (id: string) => {
    setAppointments((prev) => prev.filter((a) => a.id !== id))
  }
  const removeReport = (id: string) => {
    if (!memberId) return
    const nextReports = reports.filter((report) => report.id !== id)
    const updated = updateMemberStorage(memberId, {
      reports: nextReports,
    })
    if (updated) {
      setFamilyData({ familyName: updated.familyName, members: updated.members })
      setReports(nextReports)
    }
  }

  const openViewReportModal = (report: Report) => {
    setViewingReport(report)
    setIsReportAnalysisVisible(false)
    setReportAnalysisState({ status: 'idle' })
  }

  const getLinkedLabel = (report: Report) => (
    report.linkType === 'condition'
      ? conditions.find((c) => c.id === report.linkedId)?.name ?? 'Unknown condition'
      : appointments.find((a) => a.id === report.linkedId)?.description ?? 'Unknown appointment'
  )

  const parseAllergyReportFromText = (
    text: string,
    linkedLabel: string
  ): ReportAnalysisData => {
    const normalizedLines = text
      .split(/\r?\n/)
      .map((line) => line.trim())
      .filter(Boolean)
    const loweredLines = normalizedLines.map((line) => line.toLowerCase())

    const readMmValue = (line: string): number | null => {
      const mm = line.match(/(\d+(?:\.\d+)?)\s*mm/i)
      if (mm?.[1]) return Number(mm[1])
      const spaced = line.match(/(?:^|\s)(\d{1,2})(?:\s|$)/)
      if (spaced?.[1]) return Number(spaced[1])
      return null
    }

    const pickLineValue = (keywords: string[], label: string) => {
      const idx = loweredLines.findIndex((line) => keywords.some((kw) => line.includes(kw)))
      if (idx < 0) return null
      const line = normalizedLines[idx] ?? ''
      const value = readMmValue(line)
      return value === null ? null : { label, value }
    }

    const candidates = [
      pickLineValue(['histamine control'], 'Histamine control'),
      pickLineValue(['negative control'], 'Negative control'),
      pickLineValue(['ragweed'], 'Ragweed'),
      pickLineValue(['cat hair', 'cat epithelia'], 'Cat allergen'),
      pickLineValue(['dog epithelia', 'dog'], 'Dog allergen'),
      pickLineValue(['mite', 'd. farinae', 'd. ptero'], 'Dust mite'),
      pickLineValue(['oak', 'birch', 'cedar'], 'Tree pollen (sample row)'),
    ].filter((item): item is { label: string; value: number } => item !== null)

    const extractedValues = candidates.map((item) => `${item.label}: ${item.value} mm`)

    const histamine = candidates.find((item) => item.label === 'Histamine control')?.value
    const negative = candidates.find((item) => item.label === 'Negative control')?.value
    const positives = candidates.filter((item) => item.label !== 'Histamine control' && item.label !== 'Negative control' && item.value >= 3)

    const interpretation: string[] = []
    if (histamine !== undefined && negative !== undefined) {
      if (histamine >= 3 && negative <= 2) {
        interpretation.push('Control pattern appears technically acceptable (histamine reactive, negative control low).')
      } else {
        interpretation.push('Control pattern is less clear; clinician review is recommended before acting on allergen rows.')
      }
    }
    if (positives.length > 0) {
      interpretation.push(
        `Potential sensitization signal in ${positives.length} sampled allergen row(s) at >= 3 mm: ${positives
          .map((item) => item.label)
          .join(', ')}.`
      )
    } else {
      interpretation.push('No strong sampled allergen wheal values detected at >= 3 mm in OCR-extracted rows.')
    }
    interpretation.push(`Clinical correlation is needed with symptoms, exposure history, and provider interpretation for "${linkedLabel}".`)

    return {
      linkedLabel,
      detectedReportType: 'Allergy skin test (OCR-detected)',
      extractedValues,
      interpretation,
    }
  }

  const parseGenericMedicalReport = (
    text: string,
    linkedLabel: string
  ): ReportAnalysisData => {
    const valueMatches = Array.from(text.matchAll(/([A-Za-z][A-Za-z /()#-]{2,40})[:\s]+(\d+(?:\.\d+)?)\s*(mg\/dL|g\/dL|mm|%|bpm|ng\/mL|IU\/L|mL|cm|kg|lb)?/gi))
      .slice(0, 8)
      .map((match) => {
        const rawName = (match[1] ?? '').trim()
        const rawValue = (match[2] ?? '').trim()
        const unit = (match[3] ?? '').trim()
        return unit ? `${rawName}: ${rawValue} ${unit}` : `${rawName}: ${rawValue}`
      })

    const extractedValues = valueMatches.length > 0
      ? valueMatches
      : ['No reliably structured numeric fields were parsed from OCR text.']

    return {
      linkedLabel,
      detectedReportType: 'General clinical report',
      extractedValues,
      interpretation: [
        'Values were extracted by OCR and may include transcription errors from handwriting or scan quality.',
        'Use this summary for quick review, then confirm against the original report and clinician documentation.',
        `Tie key findings to the linked ${linkedLabel} care plan before making medication or follow-up decisions.`,
      ],
    }
  }

  const handleAnalyzeReport = async () => {
    if (!viewingReport) return
    setIsReportAnalysisVisible(true)
    setReportAnalysisState({ status: 'loading' })

    try {
      const ocr = await recognize(viewingReport.filePath, 'eng')
      const text = ocr.data.text ?? ''
      const linkedLabel = getLinkedLabel(viewingReport)
      const looksLikeAllergyReport = /allergen|histamine|negative control|dilution|endpoint/i.test(text)
      const parsed = looksLikeAllergyReport
        ? parseAllergyReportFromText(text, linkedLabel)
        : parseGenericMedicalReport(text, linkedLabel)
      setReportAnalysisState({ status: 'ready', data: parsed })
    } catch {
      setReportAnalysisState({
        status: 'error',
        message: 'Unable to analyze this image right now. Try again with a clearer scan or different image.',
      })
    }
  }

  if (!member) {
    return (
      <div className="card profile-card">
        <h1>Member profile</h1>
        <p className="profile-subtitle">
          We could not find that family member.
        </p>
        <div className="profile-actions">
          <button
            type="button"
            onClick={() =>
              navigate('/family-profile', {
                state: {
                  familyName,
                  members,
                },
              })
            }
          >
            Back to family
          </button>
        </div>
      </div>
    )
  }

  return (
    <div className="card profile-card">
      <div className="profile-header">
        <div>
          <h1>{member.firstName} {location.state?.familyName}</h1>
          <p className="profile-subtitle">{familyLabel}</p>
        </div>
      </div>

      <form key={memberId} className="modal-body profile-form" onSubmit={handleSubmit}>
        <Tabs defaultValue="basics" variant="default">
          <Tabs.List>
            <Tabs.Tab value="basics">Basic Info</Tabs.Tab>
            <Tabs.Tab value="conditions">Conditions</Tabs.Tab>
            <Tabs.Tab value="medications">Medications</Tabs.Tab>
            <Tabs.Tab value="appointments">Appointments</Tabs.Tab>
          </Tabs.List>

          <Tabs.Panel value="basics" pt="md">
            <div className="profile-section">
              {editingBasics ? (
                <>
                  <label className="field">
                    First name
                    <input
                      type="text"
                      value={firstName}
                      onChange={(event) => setFirstName(event.target.value)}
                    />
                  </label>
                  <label className="field">
                    Age
                    <input
                      type="text"
                      value={age}
                      onChange={(event) => setAge(event.target.value)}
                    />
                  </label>
                  <label className="field">
                    Role
                    <input
                      type="text"
                      value={role}
                      onChange={(event) => setRole(event.target.value)}
                    />
                  </label>
                  <button
                    type="button"
                    className="profile-done-btn"
                    onClick={() => setEditingBasics(false)}
                  >
                    Done
                  </button>
                </>
              ) : (
                <div className="profile-view-row">
                  <dl className="profile-view-dl">
                    <dt>First name</dt>
                    <dd>{firstName || '—'}</dd>
                    <dt>Age</dt>
                    <dd>{age || '—'}</dd>
                    <dt>Role</dt>
                    <dd>{role || '—'}</dd>
                  </dl>
                  <button
                    type="button"
                    className="profile-edit-icon-btn"
                    onClick={() => setEditingBasics(true)}
                    aria-label="Edit basic info"
                  >
                    <EditIcon />
                  </button>
                </div>
              )}
            </div>
          </Tabs.Panel>

          <Tabs.Panel value="conditions" pt="md">
            {conditions.length > 0 ? (
              <div className="profile-edit-list">
                {conditions.map((c) =>
                  editingConditionId === c.id ? (
                    <div key={c.id} className="profile-edit-item">
                      <label className="field">
                        Condition name
                        <input
                          type="text"
                          value={c.name}
                          onChange={(e) => updateCondition(c.id, { name: e.target.value })}
                        />
                      </label>
                      <label className="field">
                        Notes (optional)
                        <input
                          type="text"
                          value={c.notes ?? ''}
                          onChange={(e) => updateCondition(c.id, { notes: e.target.value || undefined })}
                        />
                      </label>
                      <div className="profile-edit-item-actions">
                        <button
                          type="button"
                          className="profile-done-btn"
                          onClick={() => setEditingConditionId(null)}
                        >
                          Done
                        </button>
                        <button
                          type="button"
                          className="profile-remove-btn"
                          onClick={() => { removeCondition(c.id); setEditingConditionId(null); }}
                          aria-label="Remove condition"
                        >
                          Remove
                        </button>
                      </div>
                    </div>
                  ) : (
                    <div key={c.id} className="profile-view-item">
                      <div className="profile-view-item-content">
                        <strong>{c.name}</strong>
                        {c.notes ? <span className="profile-view-notes"> — {c.notes}</span> : null}
                      </div>
                      <div className="profile-view-item-actions">
                        <button
                          type="button"
                          className="primary profile-add-report-btn"
                          onClick={() => openAddReportModal('condition', c.id)}
                        >
                          + Report
                        </button>
                        <button
                          type="button"
                          className="profile-edit-icon-btn"
                          onClick={() => setEditingConditionId(c.id)}
                          aria-label={`Edit ${c.name}`}
                        >
                          <EditIcon />
                        </button>
                      </div>
                    </div>
                  )
                )}
              </div>
            ) : (
              <p className="profile-subtitle">No conditions added yet.</p>
            )}
            <button
              type="button"
              className="primary"
              onClick={() => setAddModal('condition')}
            >
              Add Condition
            </button>
          </Tabs.Panel>

          <Tabs.Panel value="medications" pt="md">
            {medications.length > 0 ? (
              <div className="profile-edit-list">
                {medications.map((m) =>
                  editingMedicationId === m.id ? (
                    <div key={m.id} className="profile-edit-item">
                      <label className="field">
                        Medication name
                        <input
                          type="text"
                          value={m.name}
                          onChange={(e) => updateMedication(m.id, { name: e.target.value })}
                        />
                      </label>
                      <label className="field">
                        Dosage (optional)
                        <input
                          type="text"
                          value={m.dosage ?? ''}
                          onChange={(e) => updateMedication(m.id, { dosage: e.target.value || undefined })}
                        />
                      </label>
                      <label className="field">
                        Frequency (optional)
                        <input
                          type="text"
                          value={m.frequency ?? ''}
                          onChange={(e) => updateMedication(m.id, { frequency: e.target.value || undefined })}
                        />
                      </label>
                      <label className="field">
                        Notes (optional)
                        <input
                          type="text"
                          value={m.notes ?? ''}
                          onChange={(e) => updateMedication(m.id, { notes: e.target.value || undefined })}
                        />
                      </label>
                      <div className="profile-edit-item-actions">
                        <button
                          type="button"
                          className="profile-done-btn"
                          onClick={() => setEditingMedicationId(null)}
                        >
                          Done
                        </button>
                        <button
                          type="button"
                          className="profile-remove-btn"
                          onClick={() => { removeMedication(m.id); setEditingMedicationId(null); }}
                          aria-label="Remove medication"
                        >
                          Remove
                        </button>
                      </div>
                    </div>
                  ) : (
                    <div key={m.id} className="profile-view-item">
                      <div className="profile-view-item-content">
                        <strong>{m.name}</strong>
                        {m.dosage ? <span> — {m.dosage}</span> : null}
                        {m.frequency ? <span>, {m.frequency}</span> : null}
                        {m.notes ? <span className="profile-view-notes"> — {m.notes}</span> : null}
                      </div>
                      <button
                        type="button"
                        className="profile-edit-icon-btn"
                        onClick={() => setEditingMedicationId(m.id)}
                        aria-label={`Edit ${m.name}`}
                      >
                        <EditIcon />
                      </button>
                    </div>
                  )
                )}
              </div>
            ) : (
              <p className="profile-subtitle">No medications added yet.</p>
            )}
            <button
              type="button"
              className="primary"
              onClick={() => setAddModal('medication')}
            >
              Add Medication
            </button>
          </Tabs.Panel>

          <Tabs.Panel value="appointments" pt="md">
            {appointments.length > 0 ? (
              <div className="profile-edit-list">
                {appointments.map((a) =>
                  editingAppointmentId === a.id ? (
                    <div key={a.id} className="profile-edit-item">
                      <label className="field">
                        Description / type
                        <input
                          type="text"
                          value={a.description}
                          onChange={(e) => updateAppointment(a.id, { description: e.target.value })}
                        />
                      </label>
                      <label className="field">
                        Date
                        <input
                          type="date"
                          value={a.date}
                          onChange={(e) => updateAppointment(a.id, { date: e.target.value })}
                        />
                      </label>
                      <label className="field">
                        Time (optional)
                        <input
                          type="time"
                          value={a.time ?? ''}
                          onChange={(e) => updateAppointment(a.id, { time: e.target.value || undefined })}
                        />
                      </label>
                      <label className="field">
                        Location (optional)
                        <input
                          type="text"
                          value={a.location ?? ''}
                          onChange={(e) => updateAppointment(a.id, { location: e.target.value || undefined })}
                        />
                      </label>
                      <label className="field">
                        Notes (optional)
                        <input
                          type="text"
                          value={a.notes ?? ''}
                          onChange={(e) => updateAppointment(a.id, { notes: e.target.value || undefined })}
                        />
                      </label>
                      <div className="profile-edit-item-actions">
                        <button
                          type="button"
                          className="profile-done-btn"
                          onClick={() => setEditingAppointmentId(null)}
                        >
                          Done
                        </button>
                        <button
                          type="button"
                          className="profile-remove-btn"
                          onClick={() => { removeAppointment(a.id); setEditingAppointmentId(null); }}
                          aria-label="Remove appointment"
                        >
                          Remove
                        </button>
                      </div>
                    </div>
                  ) : (
                    <div key={a.id} className="profile-view-item">
                      <div className="profile-view-item-content">
                        <strong>{a.description}</strong>
                        {' — '}{a.date}
                        {a.time ? ` at ${a.time}` : null}
                        {a.location ? `, ${a.location}` : null}
                        {a.notes ? <span className="profile-view-notes"> — {a.notes}</span> : null}
                      </div>
                      <div className="profile-view-item-actions">
                        <button
                          type="button"
                          className="primary profile-add-report-btn"
                          onClick={() => openAddReportModal('appointment', a.id)}
                        >
                          + Report
                        </button>
                        <button
                          type="button"
                          className="profile-edit-icon-btn"
                          onClick={() => setEditingAppointmentId(a.id)}
                          aria-label={`Edit ${a.description}`}
                        >
                          <EditIcon />
                        </button>
                      </div>
                    </div>
                  )
                )}
              </div>
            ) : (
              <p className="profile-subtitle">No appointments scheduled yet.</p>
            )}
            <button
              type="button"
              className="primary"
              onClick={() => setAddModal('appointment')}
            >
              Add Appointment
            </button>
          </Tabs.Panel>
        </Tabs>

        <section className="profile-section">
          <h3>Reports</h3>
          {reports.length > 0 ? (
            <div className="profile-edit-list">
              {reports.map((report) => {
                const linkedLabel = report.linkType === 'condition'
                  ? conditions.find((c) => c.id === report.linkedId)?.name ?? 'Unknown condition'
                  : appointments.find((a) => a.id === report.linkedId)?.description ?? 'Unknown appointment'
                return (
                  <div key={report.id} className="profile-view-item">
                    <div className="profile-view-item-content">
                      <strong>{report.title}</strong>
                      <button
                        type="button"
                        className="profile-report-view-btn"
                        onClick={() => openViewReportModal(report)}
                        aria-label={`View report image for ${report.title}`}
                        title="View report image"
                      >
                        <PictureIcon size={16} />
                      </button>
                      <span className="profile-view-notes">
                        {' '}— linked to {report.linkType}: {linkedLabel}
                      </span>
                      <div>
                        <code>{report.filePath}</code>
                      </div>
                      {report.notes ? <span className="profile-view-notes">Notes: {report.notes}</span> : null}
                    </div>
                    <div className="profile-view-item-actions">
                      <button
                        type="button"
                        className="profile-edit-icon-btn profile-delete-icon-btn"
                        onClick={() => removeReport(report.id)}
                        aria-label={`Delete report ${report.title}`}
                      >
                        <TrashIcon />
                      </button>
                    </div>
                  </div>
                )
              })}
            </div>
          ) : (
            <p className="profile-subtitle">No reports added yet.</p>
          )}
        </section>

        <div className="profile-actions">
          <button type="button" onClick={() => navigate('/family-profile', { state: { familyName, members } })}>
            Back to family
          </button>
          <button type="submit" className="primary">
            Save changes
          </button>
        </div>
      </form>

      {/* Add Condition modal */}
      {addModal === 'condition' ? (
        <div className="modal-backdrop" onClick={closeAddModal}>
          <div className="modal" role="dialog" aria-modal="true" aria-labelledby="add-condition-title" onClick={(e) => e.stopPropagation()}>
            <div className="modal-header">
              <h3 id="add-condition-title">Add Condition</h3>
              <button type="button" className="modal-close" onClick={closeAddModal} aria-label="Close">✕</button>
            </div>
            <form className="modal-body" onSubmit={handleAddCondition}>
              <label className="field">
                Condition name
                <input type="text" value={conditionName} onChange={(e) => setConditionName(e.target.value)} placeholder="e.g. Hypertension" required />
              </label>
              <label className="field">
                Notes (optional)
                <input type="text" value={conditionNotes} onChange={(e) => setConditionNotes(e.target.value)} placeholder="Additional details" />
              </label>
              <div className="modal-actions">
                <button type="button" onClick={closeAddModal}>Cancel</button>
                <button type="submit" className="primary">Save</button>
              </div>
            </form>
          </div>
        </div>
      ) : null}

      {/* Add Medication modal */}
      {addModal === 'medication' ? (
        <div className="modal-backdrop" onClick={closeAddModal}>
          <div className="modal" role="dialog" aria-modal="true" aria-labelledby="add-medication-title" onClick={(e) => e.stopPropagation()}>
            <div className="modal-header">
              <h3 id="add-medication-title">Add Medication</h3>
              <button type="button" className="modal-close" onClick={closeAddModal} aria-label="Close">✕</button>
            </div>
            <form className="modal-body" onSubmit={handleAddMedication}>
              <label className="field">
                Medication name
                <input type="text" value={medicationName} onChange={(e) => setMedicationName(e.target.value)} placeholder="e.g. Lisinopril" required />
              </label>
              <label className="field">
                Dosage (optional)
                <input type="text" value={medicationDosage} onChange={(e) => setMedicationDosage(e.target.value)} placeholder="e.g. 10 mg" />
              </label>
              <label className="field">
                Frequency (optional)
                <input type="text" value={medicationFrequency} onChange={(e) => setMedicationFrequency(e.target.value)} placeholder="e.g. Once daily" />
              </label>
              <label className="field">
                Notes (optional)
                <input type="text" value={medicationNotes} onChange={(e) => setMedicationNotes(e.target.value)} />
              </label>
              <div className="modal-actions">
                <button type="button" onClick={closeAddModal}>Cancel</button>
                <button type="submit" className="primary">Save</button>
              </div>
            </form>
          </div>
        </div>
      ) : null}

      {/* Add Appointment modal */}
      {addModal === 'appointment' ? (
        <div className="modal-backdrop" onClick={closeAddModal}>
          <div className="modal" role="dialog" aria-modal="true" aria-labelledby="add-appointment-title" onClick={(e) => e.stopPropagation()}>
            <div className="modal-header">
              <h3 id="add-appointment-title">Add Appointment</h3>
              <button type="button" className="modal-close" onClick={closeAddModal} aria-label="Close">✕</button>
            </div>
            <form className="modal-body" onSubmit={handleAddAppointment}>
              <label className="field">
                Description / type
                <input type="text" value={appointmentDescription} onChange={(e) => setAppointmentDescription(e.target.value)} placeholder="e.g. Annual checkup" required />
              </label>
              <label className="field">
                Date
                <input type="date" value={appointmentDate} onChange={(e) => setAppointmentDate(e.target.value)} required />
              </label>
              <label className="field">
                Time (optional)
                <input type="time" value={appointmentTime} onChange={(e) => setAppointmentTime(e.target.value)} />
              </label>
              <label className="field">
                Location (optional)
                <input type="text" value={appointmentLocation} onChange={(e) => setAppointmentLocation(e.target.value)} placeholder="Clinic or address" />
              </label>
              <label className="field">
                Notes (optional)
                <input type="text" value={appointmentNotes} onChange={(e) => setAppointmentNotes(e.target.value)} />
              </label>
              <div className="modal-actions">
                <button type="button" onClick={closeAddModal}>Cancel</button>
                <button type="submit" className="primary">Save</button>
              </div>
            </form>
          </div>
        </div>
      ) : null}

      {/* Add Report modal */}
      {addModal === 'report' ? (
        <div className="modal-backdrop" onClick={closeAddModal}>
          <div className="modal" role="dialog" aria-modal="true" aria-labelledby="add-report-title" onClick={(e) => e.stopPropagation()}>
            <div className="modal-header">
              <h3 id="add-report-title">Add Report</h3>
              <button type="button" className="modal-close" onClick={closeAddModal} aria-label="Close">✕</button>
            </div>
            <form className="modal-body" onSubmit={handleAddReport}>
              <label className="field">
                Report name
                <input
                  type="text"
                  value={reportTitle}
                  onChange={(e) => setReportTitle(e.target.value)}
                  placeholder="e.g. Allergy test result"
                  required
                />
              </label>
              <label className="field">
                Report file
                <select
                  value={reportFilePath}
                  onChange={(e) => setReportFilePath(e.target.value)}
                  required
                  disabled={AVAILABLE_REPORT_PATHS.length === 0}
                >
                  <option value="">
                    {AVAILABLE_REPORT_PATHS.length === 0
                      ? 'No images found in /medical/reports'
                      : 'Select a report image'}
                  </option>
                  {AVAILABLE_REPORT_PATHS.map((path) => (
                    <option key={path} value={path}>
                      {path.replace('/medical/reports/', '')}
                    </option>
                  ))}
                </select>
              </label>
              <label className="field">
                Connect to
                <select
                  value={reportLinkType}
                  onChange={(e) => {
                    const nextType = e.target.value as ReportLinkType
                    setReportLinkType(nextType)
                    if (nextType === 'condition') {
                      setReportLinkedId(conditions[0]?.id ?? '')
                    } else {
                      setReportLinkedId(appointments[0]?.id ?? '')
                    }
                  }}
                >
                  <option value="condition">Condition</option>
                  <option value="appointment">Appointment</option>
                </select>
              </label>
              <label className="field">
                Select {reportLinkType}
                <select
                  value={reportLinkedId}
                  onChange={(e) => setReportLinkedId(e.target.value)}
                  required
                  disabled={selectedLinkOptions.length === 0}
                >
                  <option value="">
                    {selectedLinkOptions.length === 0
                      ? `No ${reportLinkType}s available`
                      : `Select a ${reportLinkType}`}
                  </option>
                  {reportLinkType === 'condition'
                    ? conditions.map((condition) => (
                      <option key={condition.id} value={condition.id}>
                        {condition.name}
                      </option>
                    ))
                    : appointments.map((appointment) => (
                      <option key={appointment.id} value={appointment.id}>
                        {appointment.description} ({appointment.date})
                      </option>
                    ))}
                </select>
              </label>
              <label className="field">
                Notes (optional)
                <input
                  type="text"
                  value={reportNotes}
                  onChange={(e) => setReportNotes(e.target.value)}
                  placeholder="Optional context"
                />
              </label>
              <div className="modal-actions">
                <button type="button" onClick={closeAddModal}>Cancel</button>
                <button
                  type="submit"
                  className="primary"
                  disabled={selectedLinkOptions.length === 0}
                >
                  Save
                </button>
              </div>
            </form>
          </div>
        </div>
      ) : null}

      {/* View Report modal */}
      {viewingReport ? (
        <div
          className="modal-backdrop modal-backdrop--report-view"
          onClick={() => {
            setViewingReport(null)
            setIsReportAnalysisVisible(false)
            setReportAnalysisState({ status: 'idle' })
          }}
        >
          <div
            className={`modal modal-report-view ${isReportAnalysisVisible ? 'modal-report-view--analyzed' : ''}`}
            role="dialog"
            aria-modal="true"
            aria-labelledby="view-report-title"
            onClick={(e) => e.stopPropagation()}
          >
            <div className="modal-header">
              <h3 id="view-report-title">{viewingReport.title}</h3>
              <button
                type="button"
                className="modal-close"
                onClick={() => {
                  setViewingReport(null)
                  setIsReportAnalysisVisible(false)
                  setReportAnalysisState({ status: 'idle' })
                }}
                aria-label="Close"
              >
                ✕
              </button>
            </div>
            <div className={`report-view-layout ${isReportAnalysisVisible ? 'report-view-layout--analyzed' : ''}`}>
              <div className="modal-body">
                <img
                  src={viewingReport.filePath}
                  alt={viewingReport.title}
                  className="report-preview-image"
                />
                <div className="modal-actions">
                  <button
                    type="button"
                    className="primary"
                    onClick={handleAnalyzeReport}
                    disabled={reportAnalysisState.status === 'loading'}
                  >
                    {reportAnalysisState.status === 'loading' ? 'Analyzing...' : 'Analyze Report'}
                  </button>
                </div>
              </div>
              {isReportAnalysisVisible ? (
                <aside className="report-analysis-panel" aria-label="Report analysis">
                  <h4>Basic Medical Analysis</h4>
                  {reportAnalysisState.status === 'loading' ? (
                    <p>Reading report image and extracting clinical values...</p>
                  ) : null}
                  {reportAnalysisState.status === 'error' ? (
                    <p>{reportAnalysisState.message}</p>
                  ) : null}
                  {reportAnalysisState.status === 'ready' ? (
                    <>
                      <p>
                        <strong>Detected type:</strong> {reportAnalysisState.data.detectedReportType}
                      </p>
                      <p>
                        <strong>Linked to:</strong>{' '}
                        {viewingReport.linkType === 'condition' ? 'Condition' : 'Appointment'} — {reportAnalysisState.data.linkedLabel}
                      </p>
                      <h5>Extracted Values</h5>
                      <ul className="report-analysis-list">
                        {reportAnalysisState.data.extractedValues.map((value) => (
                          <li key={value}>{value}</li>
                        ))}
                      </ul>
                      <h5>Interpretation</h5>
                      <ul className="report-analysis-list">
                        {reportAnalysisState.data.interpretation.map((item) => (
                          <li key={item}>{item}</li>
                        ))}
                      </ul>
                      <p>
                        Informational summary only; final interpretation should come from the treating clinician.
                      </p>
                    </>
                  ) : null}
                </aside>
              ) : null}
            </div>
          </div>
        </div>
      ) : null}
    </div>
  )
}

export default MemberProfile
