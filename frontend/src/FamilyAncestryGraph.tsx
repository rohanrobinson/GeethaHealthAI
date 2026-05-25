import { useLayoutEffect, useMemo, useRef, useState } from 'react'
import type { FamilyMember } from './familyStorage.ts'
import { buildAncestryLayout } from './familyTree.ts'

type FamilyAncestryGraphProps = {
  members: FamilyMember[]
  onMemberClick: (member: FamilyMember) => void
}

type Point = { x: number; y: number }

type ConnectorPath = {
  key: string
  d: string
  kind: 'couple' | 'parent-child'
}

function getNodeTopCenter(element: HTMLElement, container: HTMLElement): Point {
  const nodeRect = element.getBoundingClientRect()
  const containerRect = container.getBoundingClientRect()
  return {
    x: nodeRect.left - containerRect.left + nodeRect.width / 2,
    y: nodeRect.top - containerRect.top,
  }
}

function getNodeBottomCenter(element: HTMLElement, container: HTMLElement): Point {
  const nodeRect = element.getBoundingClientRect()
  const containerRect = container.getBoundingClientRect()
  return {
    x: nodeRect.left - containerRect.left + nodeRect.width / 2,
    y: nodeRect.bottom - containerRect.top,
  }
}

function horizontalPath(from: Point, to: Point): string {
  const y = (from.y + to.y) / 2
  return `M ${from.x} ${y} L ${to.x} ${y}`
}

type ParentChildGroup = {
  parentIds: string[]
  childIds: string[]
}

function groupParentChildLinks(
  links: { parentId: string; childId: string }[]
): ParentChildGroup[] {
  const childToParents = new Map<string, Set<string>>()

  for (const link of links) {
    const parents = childToParents.get(link.childId) ?? new Set<string>()
    parents.add(link.parentId)
    childToParents.set(link.childId, parents)
  }

  const groups = new Map<string, ParentChildGroup>()
  for (const [childId, parentSet] of childToParents) {
    const parentIds = [...parentSet].sort()
    const key = parentIds.join('|')
    const existing = groups.get(key)
    if (existing) {
      existing.childIds.push(childId)
      continue
    }
    groups.set(key, { parentIds, childIds: [childId] })
  }

  return [...groups.values()]
}

function parentJunction(parents: Point[]): Point {
  const x = parents.reduce((sum, point) => sum + point.x, 0) / parents.length
  const y = Math.max(...parents.map((point) => point.y))
  return { x, y }
}

function branchedParentChildPath(parents: Point[], children: Point[]): string {
  if (parents.length === 0 || children.length === 0) {
    return ''
  }

  const junction = parentJunction(parents)
  const childTopY = Math.min(...children.map((child) => child.y))
  const branchY = junction.y + (childTopY - junction.y) * 0.5
  const segments: string[] = [`M ${junction.x} ${junction.y} L ${junction.x} ${branchY}`]

  if (children.length === 1) {
    const child = children[0]
    if (Math.abs(junction.x - child.x) > 1) {
      segments.push(`L ${child.x} ${branchY}`)
    }
    segments.push(`L ${child.x} ${child.y}`)
    return segments.join(' ')
  }

  const minChildX = Math.min(...children.map((child) => child.x))
  const maxChildX = Math.max(...children.map((child) => child.x))
  segments.push(`L ${minChildX} ${branchY} L ${maxChildX} ${branchY}`)

  for (const child of children) {
    segments.push(`M ${child.x} ${branchY} L ${child.x} ${child.y}`)
  }

  return segments.join(' ')
}

function FamilyAncestryGraph({ members, onMemberClick }: FamilyAncestryGraphProps) {
  const layout = useMemo(() => buildAncestryLayout(members), [members])
  const containerRef = useRef<HTMLDivElement>(null)
  const nodeRefs = useRef(new Map<string, HTMLButtonElement>())
  const [paths, setPaths] = useState<ConnectorPath[]>([])
  const [graphSize, setGraphSize] = useState({ width: 0, height: 0 })

  const setNodeRef = (memberId: string) => (element: HTMLButtonElement | null) => {
    if (element) {
      nodeRefs.current.set(memberId, element)
      return
    }
    nodeRefs.current.delete(memberId)
  }

  useLayoutEffect(() => {
    const container = containerRef.current
    if (!container) {
      return
    }

    const measure = () => {
      const nextPaths: ConnectorPath[] = []
      const containerRect = container.getBoundingClientRect()
      setGraphSize({
        width: containerRect.width,
        height: containerRect.height,
      })

      const getBottom = (memberId: string): Point | null => {
        const node = nodeRefs.current.get(memberId)
        if (!node) {
          return null
        }
        return getNodeBottomCenter(node, container)
      }

      const getTop = (memberId: string): Point | null => {
        const node = nodeRefs.current.get(memberId)
        if (!node) {
          return null
        }
        return getNodeTopCenter(node, container)
      }

      for (const [leftId, rightId] of layout.couplePairs) {
        const left = getBottom(leftId)
        const right = getBottom(rightId)
        if (!left || !right) {
          continue
        }
        nextPaths.push({
          key: `couple-${leftId}-${rightId}`,
          kind: 'couple',
          d: horizontalPath(left, right),
        })
      }

      const parentChildGroups = groupParentChildLinks(layout.parentChildLinks)
      for (const group of parentChildGroups) {
        const parentPoints = group.parentIds
          .map((parentId) => getBottom(parentId))
          .filter((point): point is Point => point !== null)
        const childPoints = group.childIds
          .map((childId) => getTop(childId))
          .filter((point): point is Point => point !== null)

        if (parentPoints.length === 0 || childPoints.length === 0) {
          continue
        }

        const d = branchedParentChildPath(parentPoints, childPoints)
        if (!d) {
          continue
        }

        nextPaths.push({
          key: `branch-${group.parentIds.join('-')}-${group.childIds.join('-')}`,
          kind: 'parent-child',
          d,
        })
      }

      setPaths(nextPaths)
    }

    measure()

    const observer = new ResizeObserver(measure)
    observer.observe(container)
    window.addEventListener('resize', measure)

    return () => {
      observer.disconnect()
      window.removeEventListener('resize', measure)
    }
  }, [layout, members])

  if (members.length === 0) {
    return null
  }

  return (
    <section className="ancestry-graph" aria-label="Family ancestry tree">
      <div className="ancestry-graph__header">
        <h2>Family tree</h2>
        <p className="ancestry-graph__hint">
          Select parents on each member for exact links; otherwise roles (e.g. Father,
          Daughter) shape the tree.
        </p>
      </div>

      <div className="ancestry-graph__canvas" ref={containerRef}>
        <svg
          className="ancestry-graph__svg"
          width={graphSize.width}
          height={graphSize.height}
          aria-hidden="true"
        >
          {paths.map((path) => (
            <path
              key={path.key}
              d={path.d}
              className={
                path.kind === 'couple'
                  ? 'ancestry-graph__connector ancestry-graph__connector--couple'
                  : 'ancestry-graph__connector ancestry-graph__connector--parent-child'
              }
            />
          ))}
        </svg>

        <div className="ancestry-graph__tiers">
          {layout.tiers.map(({ tier, members: tierMembers }) => (
            <div className="ancestry-graph__tier" key={tier.id}>
              <p className="ancestry-graph__tier-label">{tier.label}</p>
              <div className="ancestry-graph__nodes">
                {tierMembers.map((member) => (
                  <button
                    key={member.id}
                    type="button"
                    ref={setNodeRef(member.id)}
                    className="ancestry-graph__node"
                    onClick={() => onMemberClick(member)}
                  >
                    <span className="ancestry-graph__node-name">{member.firstName}</span>
                    {member.age ? (
                      <span className="ancestry-graph__node-meta">Age {member.age}</span>
                    ) : null}
                    {member.role ? (
                      <span className="ancestry-graph__node-role">{member.role}</span>
                    ) : null}
                  </button>
                ))}
              </div>
            </div>
          ))}
        </div>
      </div>
    </section>
  )
}

export default FamilyAncestryGraph
