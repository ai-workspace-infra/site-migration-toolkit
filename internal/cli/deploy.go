package cli

import (
	"fmt"

	"github.com/spf13/cobra"
)

var deployCmd = &cobra.Command{
	Use:   "deploy [app] [environment]",
	Short: "Deploy an application",
	Args:  cobra.ExactArgs(2),
	Run: func(cmd *cobra.Command, args []string) {
		fmt.Printf("Deploying app %s to environment %s\n", args[0], args[1])
	},
}

func init() {
	rootCmd.AddCommand(deployCmd)
}
