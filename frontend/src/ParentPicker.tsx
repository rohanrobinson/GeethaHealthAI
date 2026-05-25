import type { FamilyMember } from './familyStorage.ts'

type ParentPickerProps = {
  label?: string
  hint?: string
  members: FamilyMember[]
  selectedIds: string[]
  excludeMemberId?: string
  maxParents?: number
  onChange: (parentIds: string[]) => void
}

function ParentPicker({
  label = 'Parents',
  hint = 'Optional. Links this person to parents in the family tree.',
  members,
  selectedIds,
  excludeMemberId,
  maxParents = 2,
  onChange,
}: ParentPickerProps) {
  const candidates = members.filter((member) => member.id !== excludeMemberId)

  const toggleParent = (parentId: string) => {
    if (selectedIds.includes(parentId)) {
      onChange(selectedIds.filter((id) => id !== parentId))
      return
    }
    if (selectedIds.length >= maxParents) {
      return
    }
    onChange([...selectedIds, parentId])
  }

  if (candidates.length === 0) {
    return (
      <div className="parent-picker parent-picker--empty">
        <p className="parent-picker__label">{label}</p>
        <p className="parent-picker__hint">
          Add other family members first, then you can link parents here.
        </p>
      </div>
    )
  }

  return (
    <fieldset className="parent-picker">
      <legend className="parent-picker__label">{label}</legend>
      {hint ? <p className="parent-picker__hint">{hint}</p> : null}
      <div className="parent-picker__options">
        {candidates.map((candidate) => {
          const checked = selectedIds.includes(candidate.id)
          const disabled = !checked && selectedIds.length >= maxParents
          return (
            <label
              key={candidate.id}
              className={`parent-picker__option${disabled ? ' parent-picker__option--disabled' : ''}`}
            >
              <input
                type="checkbox"
                checked={checked}
                disabled={disabled}
                onChange={() => toggleParent(candidate.id)}
              />
              <span className="parent-picker__option-text">
                {candidate.firstName}
                {candidate.role ? ` (${candidate.role})` : ''}
              </span>
            </label>
          )
        })}
      </div>
    </fieldset>
  )
}

export default ParentPicker
