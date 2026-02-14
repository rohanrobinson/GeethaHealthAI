import { useMemo, useState } from 'react'
import { useLocation, useNavigate, useParams } from 'react-router-dom'
import { Tabs } from '@mantine/core'
import {
  type Condition,
  type FamilyMember,
  type Medication,
  type Appointment,
  getFamilyStorage,
  updateMemberStorage,
} from './familyStorage.ts'

type MemberProfileState = {
  familyName?: string
  members?: FamilyMember[]
}

type AddResourceModal = 'condition' | 'medication' | 'appointment' | null

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

  const handleSubmit = (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault()
    if (!memberId) return
    const updated = updateMemberStorage(memberId, {
      firstName: firstName.trim(),
      age: age.trim(),
      role: role.trim(),
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
      conditions: [...(member.conditions ?? []), newCondition],
    })
    if (updated) {
      setFamilyData({ familyName: updated.familyName, members: updated.members })
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
      medications: [...(member.medications ?? []), newMedication],
    })
    if (updated) {
      setFamilyData({ familyName: updated.familyName, members: updated.members })
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
      appointments: [...(member.appointments ?? []), newAppointment],
    })
    if (updated) {
      setFamilyData({ familyName: updated.familyName, members: updated.members })
      closeAddModal()
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
          </Tabs.Panel>

          <Tabs.Panel value="conditions" pt="md">
            {(member?.conditions?.length ?? 0) > 0 ? (
              <ul className="profile-list">
                {member!.conditions!.map((c) => (
                  <li key={c.id}>
                    <strong>{c.name}</strong>
                    {c.notes ? ` — ${c.notes}` : null}
                  </li>
                ))}
              </ul>
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
            {(member?.medications?.length ?? 0) > 0 ? (
              <ul className="profile-list">
                {member!.medications!.map((m) => (
                  <li key={m.id}>
                    <strong>{m.name}</strong>
                    {m.dosage ? ` — ${m.dosage}` : null}
                    {m.frequency ? `, ${m.frequency}` : null}
                    {m.notes ? ` — ${m.notes}` : null}
                  </li>
                ))}
              </ul>
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
            {(member?.appointments?.length ?? 0) > 0 ? (
              <ul className="profile-list">
                {member!.appointments!.map((a) => (
                  <li key={a.id}>
                    <strong>{a.description}</strong>
                    {' — '}
                    {a.date}
                    {a.time ? ` at ${a.time}` : null}
                    {a.location ? `, ${a.location}` : null}
                    {a.notes ? ` — ${a.notes}` : null}
                  </li>
                ))}
              </ul>
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
    </div>
  )
}

export default MemberProfile
