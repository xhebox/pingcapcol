#!/bin/bash
set -e

projectID="PVT_kwDOALTl784AEfhY"
MEMBERS="xhebox bb7133 Benjamin2037 Defined2014 djshow832 hawkingrei lcwangchao mjonss tangenta tiancaiamao wjhuang2016 xiongjiwei ymkzpx zimulala YangKeao"

gdate=$(which gdate 2>/dev/null || which date 2>/dev/null || echo "date")
filter="$1"
pagesize="$2"
if [ -z "$pagesize" ]; then
	pagesize=100
fi
deleteCursor="$3"
issueCursor="$4"
pullCursor="$5"
fields=""
retry=3

graphql() {
	res=""
	jq="$1"
	query="$2"
	i=0
	while [ "$i" -lt "$retry" ]; do
		res="$(gh api graphql -f query="$query")"
		if [ "$?" -eq "0" ]; then
			res="$(echo "$res" | jq -c "$jq")"
			break
		fi
		i=$((i+1))
	done
	if [ "$i" = "$retry" ]; then
		echo "$res" >&2
		exit 1
	fi
	echo "$res"
}

getField() {
	fieldName=$1
	echo $(echo "$fields" | jq -c ".[] | select(.name == \"$fieldName\")")
}

connectedOfIssue() {
	issueNumber="$1"
	cursor=""
	while true; do
		_cursor=""
		if [ -n "$cursor" ]; then
			_cursor="after: \"$cursor\","
		fi
		res="$(graphql '.data.repository.issue.timelineItems' "query {
repository(owner: \"pingcap\", name: \"tidb\") {
	issue(number: $issueNumber) {
		timelineItems($_cursor first: $pagesize, itemTypes: CROSS_REFERENCED_EVENT) {
			nodes {
				... on CrossReferencedEvent {
					source {
						... on Issue {
							number
							repository {
								name
								owner {
									login
								}
							}
						}
						... on PullRequest {
							number
							repository {
								name
								owner {
									login
								}
							}
						}
					}
				}
			}
			pageInfo {
				hasNextPage
				endCursor
			}
		}
	}
}
}")"
		echo "$res" | jq -c '.nodes[].source' | while read -r i; do
			number="$(echo "$i" | jq -r -c '.number')"
			name="$(echo "$i" | jq -r -c '.repository.name')"
			owner="$(echo "$i" | jq -r -c '.repository.owner.login')"
			echo -n "$owner/$name#$number "
		done
		if [ "$(echo "$res" | jq -c '.pageInfo.hasNextPage')" = "false" ]; then
			break
		fi
		cursor=$(echo "$res" | jq -r -c '.pageInfo.endCursor')
	done
}

labelsOf() {
	type="$1"
	number="$2"
	cursor=""
	while true; do
		_cursor=""
		if [ -n "$cursor" ]; then
			_cursor="after: \"$cursor\","
		fi
		res="$(graphql ".data.repository.$type.labels" "query {
repository(owner: \"pingcap\", name: \"tidb\") {
	$type(number: $number) {
		labels($_cursor first: $pagesize) {
			nodes {
				name
			}
			pageInfo {
				hasNextPage
				endCursor
			}
		}
	}
}
}")"
		echo "$res" | jq -r -c '.nodes[].name' | while read -r i; do
			echo -n "$i "
		done
		if [ "$(echo "$res" | jq -c '.pageInfo.hasNextPage')" = "false" ]; then
			break
		fi
		cursor=$(echo "$res" | jq -r -c '.pageInfo.endCursor')
	done
}

processItem() {
	item="$1"

	echo "=================="
	echo "$item"
	itemID="$(echo "$item" | jq -r -c '.id' )"
	itemType="$(echo "$item" | jq -r -c '.__typename' )"
	itemNumber="$(echo "$item" | jq -r -c '.number' )"
	title="$(echo "$item" | jq -r -c '.title' )"
	closed="$(echo "$item" | jq -r -c '.closed')"
	createdAt="$(echo "$item" | jq -r -c '.createdAt')"
	updatedAt="$(echo "$item" | jq -r -c '.updatedAt')"
	trackedCount="0"
	commentCount="$(echo "$item" | jq -r -c '.comments.totalCount' )"
	assigneeCount="$(echo "$item" | jq -r -c '.assignees.totalCount' )"
	labels=""
	linkedPRs=""
	if [ "$itemType" = "Issue" ]; then
		trackedCount="$(echo "$issue" | jq -r -c '.trackedIssues.totalCount' )"
		labels="$(labelsOf "issue" "$itemNumber")"
		linkedPRs="$(connectedOfIssue "$itemNumber")"
	elif [ "$itemType" = "PullRequest" ]; then
		labels="$(labelsOf "pullRequest" "$itemNumber")"
	fi

	echo "type: $itemType"
	echo "number: $itemNumber"
	echo "closed: $closed"
	echo "comments: $commentCount"
	echo "assignees: $assigneeCount"
	echo "labels: $labels"
	echo "trackedIssues: $trackedCount"
	echo "linkedPRs: $linkedPRs"
	echo "title: $title"

	type="Issue"
	if [ "$itemType" = "Issue" ]; then
		if [ -n "$(echo "$title"  | grep -i \
			-e 'unstable.*test' \
			-e 'test.*unstable' \
			-e 'DATA RACE' \
			-e 'race.*test' \
			-e 'test.*race' \
			-e 'test.*failed' \
			-e 'failed.*test' \
			)" ]; then
			type="Test"
		fi
		if [ -n "$(echo "$labels"  | grep -i 'component/test')" ]; then
			type="Test"
		fi
	elif [ "$itemType" = "PullRequest" ]; then
		type="Pull"
	fi

	status="Todo"
	if [ "$assigneeCount" != "0" ] || [ "$linkedPRs" != "" ]; then
		status="Progress"
	fi
	if [ "$closed" = "true" ]; then
		status="Done"
	fi

	time=""
	diffDays=$(( ($($gdate '+%s') - $($gdate --date=$updatedAt '+%s')) / 86400 ))
	if [ "$diffDays" -le 7 ]; then
		time="1W"
	elif [ "$diffDays" -le 14 ]; then
		time="2W"
	elif [ "$diffDays" -le 30 ]; then
		time="1M"
	elif [ "$diffDays" -le 60 ]; then
		time="2M"
	elif [ "$diffDays" -le 90 ]; then
		time="3M"
	else
		time="Inactive"
	fi
	echo "createdAt: $createdAt"
	echo "type: $type"
	echo "updatedAt: $updatedAt"
	echo "status: $status"
	echo "time: $time"

	if [ "$time" = "Inactive" -a "$status" = "Done" ]; then
		return
	fi

	itemID="$(graphql '.data.addProjectV2ItemById.item.id' "mutation {
addProjectV2ItemById(input: {projectId: \"$projectID\", contentId: \"$itemID\"}) {
	item {
		id
	}
}
}" | jq -r)"
	echo "itemID: $itemID"

	typeField="$(getField "Type")"
	typeFieldID="$(echo $typeField | jq -r -c ".id" )"
	typeFieldOptionID="$(echo $typeField | jq -r -c ".options[] | select(.name == \"$type\") | .id")"
	statusField="$(getField "Status")"
	statusFieldID="$(echo $statusField | jq -r -c ".id")"
	statusFieldOptionID="$(echo $statusField | jq -r -c ".options[] | select(.name == \"$status\") | .id")"
	timeField="$(getField "Time")"
	timeFieldID="$(echo $timeField | jq -r -c ".id" )"
	timeFieldOptionID="$(echo $timeField | jq -r -c ".options[] | select(.name == \"$time\") | .id")"
	createdAtFieldID="$(getField "CreatedAt" | jq -r -c ".id" )"
	updatedAtFieldID="$(getField "UpdatedAt" | jq -r -c ".id" )"

	updatedResult="$(graphql '.data' "mutation {
type: updateProjectV2ItemFieldValue(
input: {
	projectId: \"$projectID\"
	itemId: \"$itemID\"
	fieldId: \"$typeFieldID\"
	value: {
		singleSelectOptionId: \"$typeFieldOptionID\"
	}
}) {
	projectV2Item {
		id
	}
}
status: updateProjectV2ItemFieldValue(
input: {
	projectId: \"$projectID\"
	itemId: \"$itemID\"
	fieldId: \"$statusFieldID\"
	value: {
		singleSelectOptionId: \"$statusFieldOptionID\"
	}
}) {
	projectV2Item {
		id
	}
}
create: updateProjectV2ItemFieldValue(
input: {
	projectId: \"$projectID\"
	itemId: \"$itemID\"
	fieldId: \"$createdAtFieldID\"
	value: {
		date: \"$createdAt\"
	}
}) {
	projectV2Item {
		id
	}
}
update: updateProjectV2ItemFieldValue(
input: {
	projectId: \"$projectID\"
	itemId: \"$itemID\"
	fieldId: \"$updatedAtFieldID\"
	value: {
		date: \"$updatedAt\"
	}
}) {
	projectV2Item {
		id
	}
}
time: updateProjectV2ItemFieldValue(
input: {
	projectId: \"$projectID\"
	itemId: \"$itemID\"
	fieldId: \"$timeFieldID\"
	value: {
		singleSelectOptionId: \"$timeFieldOptionID\"
	}
}) {
	projectV2Item {
		id
	}
}
}")" > /dev/null
	if [ -z "$updatedResult" ]; then
		echo "failed to update item[$itemID]"
		exit 3
	else
		echo "updated item[$itemID]"
	fi
}

archiveInactiveDone() {
	true
}

init() {
	echo "###################### init"
	fields="$(graphql '.data.node.fields.nodes' "query{
node(id: \"$projectID\") {
	... on ProjectV2 {
		fields(first: 100) {
			nodes {
				... on ProjectV2Field {
					id
					name
				}
				... on ProjectV2IterationField {
					id
					name
					configuration {
						iterations {
							startDate
							id
						}
					}
				}
				... on ProjectV2SingleSelectField {
					id
					name
					options {
						id
						name
					}
				}
			}
		}
	}
}
}")"

	echo "###################### delete inactive done"
	cursor="$deleteCursor"
	while true; do
		_cursor=""
		if [ -n "$cursor" ]; then
			_cursor="after: \"$cursor\","
		fi
		res="$(graphql '.data.node.items' "query{
node(id: \"$projectID\") {
	... on ProjectV2 {
		items($_cursor first: $pagesize) {
			nodes {
				id
				status: fieldValueByName(name: \"Status\") {
					... on ProjectV2ItemFieldSingleSelectValue {
						name
					}
				}
				time: fieldValueByName(name: \"Time\") {
					... on ProjectV2ItemFieldSingleSelectValue {
						name
					}
				}
			}
			pageInfo {
				hasNextPage
				endCursor
			}
		}
	}
}
}")"
		echo "$res" | jq -c '.nodes[]' | while read -r item; do
			itemID="$(echo $item | jq -r -c '.id')"
			itemStatus="$(echo "$item" | jq -r -c '.status.name' )"
			itemTime="$(echo "$item" | jq -r -c '.time.name' )"
			if [ "$itemTime" = "Inactive" -a "$itemStatus" = "Done" ]; then
				id="$(graphql '.data.deleteProjectV2Item.deletedItemId' "mutation {
		deleteProjectV2Item(input: {projectId: \"$projectID\", itemId: \"$itemID\"}) {
			deletedItemId
		}
		}")"
				echo "deleted [$itemID]"
				if [ -z "$id" -o "$id" = "\"\"" ]; then
					echo "failed to delete"
					exit 2
				fi
			fi
		done
		echo "done page[$cursor]"
		if [ "$(echo "$res" | jq -c '.pageInfo.hasNextPage')" = "false" ]; then
			break
		fi
		cursor=$(echo "$res" | jq -r -c '.pageInfo.endCursor')
	done
}

main() {
	text=$1

	echo "###################### update issues [$text]"
	cursor="$issueCursor"
	while true; do
		_cursor=""
		if [ -n "$cursor" ]; then
			_cursor="after: \"$cursor\","
		fi
		res="$(graphql '.data.search' "query {
search($_cursor, type: ISSUE, first: $pagesize, query: \"repo:pingcap/tidb $text\") {
	nodes {
		__typename
		... on Issue {
			id
			number
			title
			comments {
				totalCount
			}
			assignees {
				totalCount
			}
			trackedIssues {
				totalCount
			}
			author {
				login
			}
			closed
			closedAt
			createdAt
			updatedAt
		}
	}
	pageInfo {
		hasNextPage
		endCursor
	}
}
}")"
		echo "$res" | jq -c '.nodes[]' | while read -r item; do
			typename="$(echo $item | jq -r -c '.__typename')"
			if [ "$typename" = "Issue" ]; then
				processItem "$item"
			fi
		done
		echo "done page[$cursor]"
		if [ "$(echo "$res" | jq -c '.pageInfo.hasNextPage')" = "false" ]; then
			break
		fi
		cursor=$(echo "$res" | jq -r -c '.pageInfo.endCursor')
	done

	echo "###################### update pull requests [$text]"
	cursor="$pullCursor"
	while true; do
		_cursor=""
		if [ -n "$cursor" ]; then
			_cursor="after: \"$cursor\","
		fi
		res="$(graphql '.data.search' "query {
search($_cursor, type: ISSUE, first: $pagesize, query: \"repo:pingcap/tidb is:pr $text\") {
	nodes {
		__typename
		... on PullRequest {
			id
			number
			title
			comments {
				totalCount
			}
			assignees {
				totalCount
			}
			author {
				login
			}
			closed
			closedAt
			createdAt
			updatedAt
		}
	}
	pageInfo {
		hasNextPage
		endCursor
	}
}
}")"
		echo "$res" | jq -c '.nodes[]' | while read -r item; do
			typename="$(echo $item | jq -r -c '.__typename')"
			if [ "$typename" = "PullRequest" ]; then
				processItem "$item"
			fi
		done
		echo "done page[$cursor]"
		if [ "$(echo "$res" | jq -c '.pageInfo.hasNextPage')" = "false" ]; then
			break
		fi
		cursor=$(echo "$res" | jq -r -c '.pageInfo.endCursor')
	done
}

init
main "label:sig/sql-infra $filter"
for i in $MEMBERS; do
	main "author:$i $filter"
done
